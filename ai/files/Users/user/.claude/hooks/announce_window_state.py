#!/usr/bin/env python3
"""Drive terminal window state from Claude Code hook events.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the front window id, label the tab `[RUNNING]`.
  Notification -> Claude is waiting on you: `[READY]` title, Dock bounce,
                  desktop notification (a click raises the window under
                  Hammerspoon), and pull the window frontmost unless
                  the terminal app is already frontmost (you may be typing).
  PostToolUse  -> a tool finished (including one you just approved): reset to
                  `[RUNNING]`.

Each event also records the session's state word (busy, decision or ready) to
/tmp/claude-state-hook/<session_id>.state for Hammerspoon's page dots, which
watch that folder; SessionEnd deletes it along with the window record. Once the
state moves off "decision" (a prompt answered, a new turn, the turn ending),
nothing waits on the user anymore, so the Hammerspoon notification is withdrawn.

No wrapper process sits in the I/O path. The script reaches the Terminal tab by
writing OSC/bell bytes straight to the claude process's controlling tty, and
focuses the window via the id captured at launch. The objective in the title is
the session's caveman summary at /tmp/claude/<short-session-id>/objective (the
assistant writes it on the first user message, and the statusline shows the
same line), else CLAUDE_OBJECTIVE (set by `cl --obj "..."`, aliased `clo`).

The title, bell, and notification work in any terminal. The window capture and
raise pick their mechanism by the emulator claude runs in, read off TERM_PROGRAM:

  Terminal.app  -> Terminal's AppleScript dictionary. Under any other emulator
                   that `tell application "Terminal"` would launch Terminal.app
                   just to answer, popping up an empty window.
  anything else -> Hammerspoon's command-line client (`hs -c`, needs `hs.ipc`
                   loaded in its config), since emulators like Ghostty have no
                   scripting dictionary and Hammerspoon already holds the
                   accessibility grant. Hammerspoon only sees each window's
                   visible tab, so a session sitting in a background tab gets
                   its app activated rather than its tab switched to.

A missing macOS permission or client must never break Claude, so every skipped
step and osascript or Hammerspoon failure fails soft and is recorded to a log
instead. An installed Hammerspoon client that can't reach the app also posts a
desktop notification once per session, since that is a misconfiguration rather
than a machine without Hammerspoon. Tail the log while debugging "nothing happened":

  tail -f /tmp/claude-state-hook/announce_window_state.log
"""

import fcntl
import hashlib
import json
import os
import subprocess
import sys
from collections.abc import Generator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from claude_session_dir import claude_session_dir
from terminal_tty import IN_TERMINAL_APP
from terminal_tty import STATE_DIR
from terminal_tty import append_log
from terminal_tty import controlling_tty
from terminal_tty import write_to_terminal

LOG_FILE = STATE_DIR / "announce_window_state.log"
WINDOW_OBJECTIVE = os.environ.get("CLAUDE_OBJECTIVE", "Claude Code")

# Reach Hammerspoon through the client shipped inside its bundle rather than a
# PATH lookup, since hooks run with claude's environment, not the login shell's.
HAMMERSPOON_CLI = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"

# Map each notification type to the session state it signals; leave the rest (e.g. "auth_success") unmapped.
NOTIFICATION_STATES = {
    "elicitation_dialog": "decision",
    "elicitation_url_dialog": "decision",
    "idle_prompt": "ready",
    "permission_prompt": "decision",
}


@dataclass(frozen=True)
class Session:
    """A Claude session's id and the records filed under it in `STATE_DIR`."""

    id: str

    def record_file(self, suffix: str) -> Path:
        """
        Returns the session's record file with the given suffix.

        :param suffix: Extension naming the record (e.g. "state").
        :return: Path under `STATE_DIR` named for the session id.
        """
        return STATE_DIR / f"{self.id}.{suffix}"

    @property
    def hammerspoon_alerted_file(self) -> Path:
        """Returns the marker that the Hammerspoon-unreachable alert already fired."""
        return self.record_file(suffix="hammerspoon_alerted")

    @property
    def lock_file(self) -> Path:
        """Returns the file the session's state writes lock on."""
        return self.record_file(suffix="lock")

    @property
    def notified_file(self) -> Path:
        """Returns the marker that Hammerspoon posted a notification for the session."""
        return self.record_file(suffix="notified")

    @property
    def state_file(self) -> Path:
        """Returns the file holding the session's state word for Hammerspoon's page dots."""
        return self.record_file(suffix="state")

    @property
    def stop_blocked_file(self) -> Path:
        """Returns the file fingerprinting the last stop a sibling Stop hook blocked."""
        return self.record_file(suffix="stop_blocked")

    @property
    def waiting_tool_file(self) -> Path:
        """Returns the file naming the tool whose prompt waits on the user."""
        return self.record_file(suffix="waiting_tool")

    @property
    def window_file(self) -> Path:
        """Returns the file holding the window captured at session launch."""
        return self.record_file(suffix="window")


def log(message: str) -> None:
    """Append a timestamped diagnostic line so soft failures stay visible."""
    append_log(LOG_FILE, message)


def applescript_quote(text: str) -> str:
    """Escape a string for safe interpolation into an AppleScript literal."""
    return text.replace("\\", "\\\\").replace('"', '\\"')


def run_osascript(script: str, action: str) -> subprocess.CompletedProcess[str]:
    """Run an AppleScript snippet, logging any failure with a permission hint."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        stderr = result.stderr.strip()
        log(f"{action} failed (osascript exit {result.returncode}): {stderr}")
        # -1743 is macOS's "not authorized to send Apple events": Automation is off.
        if "-1743" in stderr or "Not authorized" in stderr:
            log("  fix: System Settings > Privacy & Security > Automation > Terminal > enable Terminal")

    return result


def alert_hammerspoon_unreachable(session: Session) -> None:
    """
    Post a desktop notification that Hammerspoon's client can't reach the app, once per session.

    :param session: Claude session the once-only marker is filed under.
    """
    marker = session.hammerspoon_alerted_file

    if marker.exists():
        return

    marker.touch()
    run_osascript(
        'display notification "Window capture and raise are off. Check Hammerspoon is running with require(\'hs.ipc\') in its init.lua." with title "Hammerspoon unreachable"',
        "post Hammerspoon alert",
    )


def run_hammerspoon(
    lua: str,
    action: str,
    session: Session,
) -> str | None:
    """
    Run a Lua snippet inside Hammerspoon, returning its printed result or None on failure.

    :param lua: Lua source for `hs -c`; its `return` value comes back as text.
    :param action: Short label for the log line (e.g. "capture window id").
    :param session: Claude session whose once-only failure alert this may fire.
    :return: The snippet's return value, stripped, or None when the client is
        missing or the snippet errored.
    """
    try:
        result = subprocess.run(
            [HAMMERSPOON_CLI, "-c", lua],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as error:
        log(f"{action} failed (no Hammerspoon client at {HAMMERSPOON_CLI}): {error}")
        return None

    if result.returncode != 0:
        log(f"{action} failed (hs exit {result.returncode}): {result.stderr.strip()}")
        log("  fix: Hammerspoon must be running with `require('hs.ipc')` in its init.lua")
        # Alert only here, not on a missing client above: an installed client that can't connect is a misconfiguration.
        alert_hammerspoon_unreachable(session=session)
        return None

    return result.stdout.strip()


def write_to_own_tab(payload: str) -> None:
    """
    Send raw bytes straight to the session's tab, bypassing the hook pipe.

    :param payload: Escape sequence or bell to emit, terminator included.
    """
    dev = controlling_tty()

    if dev is None:
        log(f"no controlling tty for ppid {os.getppid()}; title/bell skipped")
        return

    error = write_to_terminal(dev, payload)

    if error is not None:
        log(f"write to {dev} failed: {error}")


def objective(session: Session) -> str:
    """
    Returns the objective to label this session's window with.

    Prefers the session's caveman summary marker, which the statusline renders
    too, so the title and the bar name the work the same way. Falls back to the
    window-scoped `WINDOW_OBJECTIVE` before the marker exists (SessionStart, the
    first prompt) or when the session id is missing.

    :param session: Claude session whose marker to read.
    :return: First line of the objective marker, else `WINDOW_OBJECTIVE`.
    """
    session_dir = claude_session_dir(session.id)

    if session_dir is None:
        return WINDOW_OBJECTIVE

    try:
        first_line = (session_dir / "objective").read_text().partition("\n")[0].strip()
    except OSError:
        return WINDOW_OBJECTIVE

    return first_line or WINDOW_OBJECTIVE


def set_title(
    state: str,
    session: Session,
) -> None:
    """
    Set the tab/window title to `[STATE] <Objective>` via an OSC escape.

    :param state: Label for the bracket (e.g. "RUNNING", "READY").
    :param session: Claude session whose objective fills the title.
    """
    write_to_own_tab(f"\033]0;[{state}] {objective(session=session)}\007")


def record_session_state(
    session: Session,
    state: str,
) -> None:
    """
    Record the session's state word for Hammerspoon's page dots to read.

    Writes through a temp file and a rename, so the folder watcher never reads
    a half-written word. Skips the write when the file already holds the word,
    since every write sets off a full page-dots refresh in Hammerspoon.

    :param session: Claude session the state is filed under.
    :param state: One of "busy", "decision" or "ready".
    """
    if not session.id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = session.state_file

    try:
        recorded = path.read_text()
    except OSError:
        recorded = None

    if recorded == state:
        return

    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_text(state)
    temporary.replace(path)

    if state != "decision":
        withdraw_notification(session=session)


def withdraw_notification(session: Session) -> None:
    """
    Withdraw the session's Hammerspoon notification once nothing waits on the user.

    Skips the Hammerspoon call unless a notification was posted, since the
    state changes on every turn. An `osascript` notification can't be
    withdrawn, so a Terminal.app session never records one.

    :param session: Claude session whose notification to withdraw.
    """
    marker = session.notified_file

    if not marker.exists():
        return

    marker.unlink(missing_ok=True)
    record = recorded_window(session=session)

    if not record:
        return

    window_id = record[0]
    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        return require("notify_claude_session_windows").withdraw({window_id}, {lua_quote(bundle_id)})
        """,
        action="withdraw notification",
        session=session,
    )

    if outcome:
        log(outcome)


def record_waiting_tool(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session as waiting on the user to answer a prompt for the event's tool.

    :param session: Claude session the record is filed under.
    :param event: PermissionRequest or PreToolUse payload naming the tool.
    """
    if not session.id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    session.waiting_tool_file.write_text(event.get("tool_name", ""))
    record_session_state(session=session, state="decision")


def record_tool_finished(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session busy once a tool finishes, unless another tool's prompt still waits.

    Parallel tool calls let a sibling finish while a prompt is up, so only the
    waiting tool's own result ends the decision. Its name stands in for the
    call, since its input can change once answered (e.g. `AskUserQuestion`).

    :param session: Claude session the record is filed under.
    :param event: PostToolUse or PostToolUseFailure payload naming the tool.
    """
    try:
        waiting_tool = session.waiting_tool_file.read_text()
    except OSError:
        record_session_state(session=session, state="busy")
        return

    if waiting_tool != event.get("tool_name", ""):
        return

    session.waiting_tool_file.unlink(missing_ok=True)
    record_session_state(session=session, state="busy")


def record_turn_state(
    session: Session,
    state: str,
) -> None:
    """
    Record a state that ends any prompt the session was waiting on.

    :param session: Claude session the state is filed under.
    :param state: "busy" on a new prompt, "ready" once the turn ends.
    """
    if not session.id:
        return

    session.waiting_tool_file.unlink(missing_ok=True)
    record_session_state(session=session, state=state)


@contextmanager
def session_lock(session: Session) -> Generator[None]:
    """
    Hold the session's lock, so Stop hooks running in parallel can't interleave their state writes.

    :param session: Claude session whose lock to hold.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    with open(session.lock_file, "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def stop_fingerprint(event: dict[str, Any]) -> str:
    """
    Returns a fingerprint of the stop, the same for every Stop hook that sees it.

    :param event: Stop hook payload, which each parallel Stop hook receives unchanged.
    :return: Hex digest of the stopping message.
    """
    return hashlib.sha256((event.get("last_assistant_message") or "").encode()).hexdigest()


def record_stop(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session ready once its turn ends, unless a sibling Stop hook blocked this stop.

    :param session: Claude session the state is filed under.
    :param event: Stop hook payload.
    """
    if not session.id:
        return

    with session_lock(session=session):
        try:
            blocked = session.stop_blocked_file.read_text()
        except OSError:
            blocked = ""

        if blocked == stop_fingerprint(event=event):
            return

        record_turn_state(session=session, state="ready")


def record_stop_blocked(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session busy again when a Stop hook sends Claude back to work.

    The blocking hooks call this themselves (event "StopBlocked"), since no
    event fires when Claude resumes. The fingerprint stops this session's own
    Stop handler, running in parallel, from writing "ready" after it.

    :param session: Claude session the state is filed under.
    :param event: The Stop hook payload the blocking hook received.
    """
    if not session.id:
        return

    with session_lock(session=session):
        session.stop_blocked_file.write_text(stop_fingerprint(event=event))
        record_session_state(session=session, state="busy")


def forget_session(session: Session) -> None:
    """
    Delete the session's state and window records, so its page dot goes back to no session.

    :param session: Claude session whose records to delete.
    """
    if not session.id:
        return

    withdraw_notification(session=session)
    session.state_file.unlink(missing_ok=True)
    session.waiting_tool_file.unlink(missing_ok=True)
    session.stop_blocked_file.unlink(missing_ok=True)
    session.lock_file.unlink(missing_ok=True)
    session.window_file.unlink(missing_ok=True)


def capture_window_id(session: Session) -> None:
    """
    Record the frontmost window at session launch.

    Terminal.app yields a bare window id. Hammerspoon yields the window id and
    the owning app's bundle id, space-separated, so the raise can fall back to
    activating the app when the window has slipped behind another tab.

    :param session: Claude session the record is filed under.
    """
    if IN_TERMINAL_APP:
        result = run_osascript(
            'tell application "Terminal" to id of front window',
            "capture window id",
        )

        if result.returncode != 0:
            return

        record = result.stdout.strip()
    else:
        record = run_hammerspoon(
            lua="""
            local window = hs.window.focusedWindow()
            if window == nil or window:id() == nil then
                return ""
            end
            return string.format("%d %s", window:id(), window:application():bundleID() or "")
            """,
            action="capture window id",
            session=session,
        )

        if not record:
            log(f"no focused window at launch; cannot record one for session {session.id}")
            return

    session.window_file.write_text(record)
    log(f"captured window {record} for session {session.id}")


def recorded_window(session: Session) -> list[str] | None:
    """
    Returns the session's window record split into its fields.

    :param session: Claude session whose window record to read.
    :return: Window id, then the owning app's bundle id under Hammerspoon
        (e.g. `["12345", "com.mitchellh.ghostty"]`), or None when no record is on file.
    """
    path = session.window_file

    if not path.exists():
        return None

    return path.read_text().strip().split()


def raise_window_lua(
    window_id: str,
    bundle_id: str,
) -> str:
    """
    Returns Lua statements that focus a window, falling back to activating its app.

    :param window_id: Hammerspoon window id to focus (e.g. "12345").
    :param bundle_id: Bundle id of the app to activate when the window is gone
        or sits in a background tab (e.g. "com.mitchellh.ghostty").
    :return: Lua source whose `return` reports what got raised.
    """
    return f"""
        return require("notify_claude_session_windows").raise({window_id}, {lua_quote(bundle_id)})
        """


def focus_window(session: Session) -> None:
    """
    Force the recorded window to the frontmost layer.

    :param session: Claude session whose window record to raise.
    """
    record = recorded_window(session=session)

    if record is None:
        log(f"no window id on file for session {session.id}; cannot raise (was SessionStart blocked?)")
        return
    elif not record:
        return

    window_id = record[0]

    # Leave focus alone while a window of the session's own terminal app is
    # frontmost: the user may be mid-keystroke in another session, and a raise
    # would redirect their typing. The title, bell and notification still fire.
    if IN_TERMINAL_APP:
        result = run_osascript(
            'tell application "Terminal" to get frontmost',
            "check Terminal focus",
        )

        if result.returncode == 0 and result.stdout.strip() == "true":
            log(f"Terminal is frontmost (typing?); window {window_id} left alone")
            return

        run_osascript(
            f'tell application "Terminal" to set frontmost of window id {window_id} to true',
            f"raise window {window_id}",
        )
        return

    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        local focused = hs.window.focusedWindow()
        if focused ~= nil and focused:application():bundleID() == "{bundle_id}" then
            return "{bundle_id} is frontmost (typing?); window {window_id} left alone"
        end
        {raise_window_lua(window_id=window_id, bundle_id=bundle_id)}
        """,
        action=f"raise window {window_id}",
        session=session,
    )

    if outcome:
        log(outcome)


def lua_quote(text: str) -> str:
    """
    Returns a Lua long-bracket string literal holding the text verbatim.

    :param text: Text to embed (e.g. a notification body).
    :return: The text wrapped in `[[` and `]]`, padded with enough `=` that
        no `]]` inside the text closes it early.
    """
    level = 0

    while f"]{'=' * level}]" in text:
        level += 1

    equals = "=" * level
    return f"[{equals}[{text}]{equals}]"


def post_osascript_notification(
    message: str,
    title: str,
) -> None:
    """
    Post a notification through `osascript`, which macOS files under Script Editor.

    :param message: Notification body (e.g. the hook payload's message).
    :param title: Notification title (e.g. the session's objective).
    """
    script = f'display notification "{applescript_quote(message)}" with title "{applescript_quote(title)}"'

    result = run_osascript(script, "post notification")

    if result.returncode == 0:
        log("notification dispatched; if invisible, allow Script Editor in System Settings > Notifications")


def post_clickable_notification(
    message: str,
    title: str,
    session: Session,
) -> bool:
    """
    Post a notification through Hammerspoon that raises the session's window when clicked.

    :param message: Notification body (e.g. the hook payload's message).
    :param title: Notification title (e.g. the session's objective).
    :param session: Claude session whose recorded window the click raises.
    :return: True once Hammerspoon posted it; False when no window is on file
        or Hammerspoon can't be reached, so the caller can fall back.
    """
    record = recorded_window(session=session)

    # Fall back when no window is on file (None) or the record is empty.
    if not record:
        return False

    window_id = record[0]
    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        return require("notify_claude_session_windows").post(
            {window_id},
            {lua_quote(bundle_id)},
            {lua_quote(title)},
            {lua_quote(message)}
        )
        """,
        action="post clickable notification",
        session=session,
    )

    if outcome is None:
        return False

    session.notified_file.write_text("")
    log(outcome)
    return True


def notify(
    message: str,
    session: Session,
) -> None:
    """
    Fire a silent native desktop notification.

    Silent because `chime_when_waiting_on_user_to_answer.sh` already chimes on
    this event, debounced across sessions; a sound here would double it.

    Hammerspoon posts it when it can, since its click callback raises the
    session's window; clicking an `osascript` notification opens Script Editor.

    :param message: Notification body (e.g. the hook payload's message).
    :param session: Claude session whose objective titles the notification.
    """
    title = objective(session=session)

    if IN_TERMINAL_APP:
        post_osascript_notification(message=message, title=title)
        return
    elif post_clickable_notification(message=message, title=title, session=session):
        return

    post_osascript_notification(message=message, title=title)


def on_waiting(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    React to a wait-state: title, Dock bounce, notification, focus.

    :param session: Claude session waiting on the user.
    :param event: Notification hook payload.
    """
    set_title(state="READY", session=session)

    # Emit the bell straight to the terminal to bounce the Dock icon.
    write_to_own_tab("\a")

    message = event.get("message") or "Awaiting your approval"
    notify(message=message, session=session)
    focus_window(session=session)


def record_notification_state(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Record the state a notification puts the session in, by its `notification_type`.

    A prompt the user has to answer is a decision; the idle notice only means
    the turn is over. Other notifications (e.g. "auth_success") leave the state alone.

    :param session: Claude session the state is filed under.
    :param event: Notification hook payload.
    """
    state = NOTIFICATION_STATES.get(event.get("notification_type", ""))

    if state is None:
        return
    elif state == "ready":
        record_turn_state(session=session, state=state)
        return

    record_session_state(session=session, state=state)


def main() -> None:
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event: dict[str, Any] = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    session = Session(id=event.get("session_id", ""))

    if event_name == "SessionStart":
        log(f"SessionStart: objective={objective(session=session)!r}")
        capture_window_id(session=session)
        set_title(state="RUNNING", session=session)
        # Skip a compaction's restart, which can land mid-turn while the session is still busy.
        if event.get("source") != "compact":
            record_session_state(session=session, state="ready")
    elif event_name == "Notification":
        log(
            "Notification: objective={!r} type={!r} message={!r}".format(
                objective(session=session), event.get("notification_type"), event.get("message")
            )
        )
        record_notification_state(session=session, event=event)
        on_waiting(session=session, event=event)
    elif event_name == "PermissionRequest":
        record_waiting_tool(session=session, event=event)
    elif event_name == "PreToolUse":
        # Mark a tool that waits on the user's answer (wired by matcher in settings.json).
        record_waiting_tool(session=session, event=event)
    elif event_name == "PostToolUse":
        set_title(state="RUNNING", session=session)
        record_tool_finished(session=session, event=event)
    elif event_name == "PostToolUseFailure":
        record_tool_finished(session=session, event=event)
    elif event_name == "SessionEnd":
        forget_session(session=session)
    elif event_name == "Stop":
        record_stop(session=session, event=event)
    elif event_name == "StopBlocked":
        record_stop_blocked(session=session, event=event)
    elif event_name == "UserPromptSubmit":
        record_turn_state(session=session, state="busy")


if __name__ == "__main__":
    main()
