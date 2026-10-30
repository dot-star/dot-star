#!/usr/bin/env python3
"""Drive terminal window state from Claude Code hook events.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the front window id, label the tab `[RUNNING]`.
  Notification -> Claude is waiting on you: `[READY]` title, Dock bounce,
                  desktop notification, and pull the window frontmost unless
                  the terminal app is already frontmost (you may be typing).
  PostToolUse  -> a tool finished (including one you just approved): reset to
                  `[RUNNING]`.

Each event also records the session's state word (busy, decision or ready) to
/tmp/claude-state-hook/<session_id>.state for Hammerspoon's page dots, which
watch that folder; SessionEnd deletes it along with the window record.

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
from pathlib import Path

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


def alert_hammerspoon_unreachable(session_id: str) -> None:
    """
    Post a desktop notification that Hammerspoon's client can't reach the app, once per session.

    :param session_id: Claude session id the once-only marker is filed under.
    """
    marker = STATE_DIR / f"{session_id}.hammerspoon_alerted"

    if marker.exists():
        return

    marker.touch()
    run_osascript(
        'display notification "Window capture and raise are off. Check Hammerspoon is running with require(\'hs.ipc\') in its init.lua." with title "Hammerspoon unreachable"',
        "post Hammerspoon alert",
    )


def run_hammerspoon(lua: str, action: str, session_id: str) -> str | None:
    """
    Run a Lua snippet inside Hammerspoon, returning its printed result or None on failure.

    :param lua: Lua source for `hs -c`; its `return` value comes back as text.
    :param action: Short label for the log line (e.g. "capture window id").
    :param session_id: Claude session id whose once-only failure alert this may fire.
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
        alert_hammerspoon_unreachable(session_id)
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


def objective(session_id: str) -> str:
    """
    Returns the objective to label this session's window with.

    Prefers the session's caveman summary marker, which the statusline renders
    too, so the title and the bar name the work the same way. Falls back to the
    window-scoped `WINDOW_OBJECTIVE` before the marker exists (SessionStart, the
    first prompt) or when the session id is missing.

    :param session_id: Claude session id whose marker to read.
    :return: First line of the objective marker, else `WINDOW_OBJECTIVE`.
    """
    session_dir = claude_session_dir(session_id)

    if session_dir is None:
        return WINDOW_OBJECTIVE

    try:
        first_line = (session_dir / "objective").read_text().partition("\n")[0].strip()
    except OSError:
        return WINDOW_OBJECTIVE

    return first_line or WINDOW_OBJECTIVE


def set_title(state: str, session_id: str) -> None:
    """
    Set the tab/window title to `[STATE] <Objective>` via an OSC escape.

    :param state: Label for the bracket (e.g. "RUNNING", "READY").
    :param session_id: Claude session id whose objective fills the title.
    """
    write_to_own_tab(f"\033]0;[{state}] {objective(session_id)}\007")


def window_file(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.window"


def session_state_file(session_id: str) -> Path:
    """
    Returns the file holding the session's state word for Hammerspoon's page dots.

    :param session_id: Claude session id the state is filed under.
    :return: Path beside the session's `.window` record.
    """
    return STATE_DIR / f"{session_id}.state"


def record_session_state(session_id: str, state: str) -> None:
    """
    Record the session's state word for Hammerspoon's page dots to read.

    Writes through a temp file and a rename, so the folder watcher never reads
    a half-written word.

    :param session_id: Claude session id the state is filed under.
    :param state: One of "busy", "decision" or "ready".
    """
    if not session_id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = session_state_file(session_id)
    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_text(state)
    temporary.replace(path)


def waiting_tool_file(session_id: str) -> Path:
    """
    Returns the file naming the tool whose prompt waits on the user.

    :param session_id: Claude session id the record is filed under.
    :return: Path beside the session's `.state` record.
    """
    return STATE_DIR / f"{session_id}.waiting_tool"


def record_waiting_tool(event: dict) -> None:
    """
    Mark the session as waiting on the user to answer a prompt for the event's tool.

    :param event: PermissionRequest or PreToolUse payload naming the tool.
    """
    session_id = event.get("session_id", "")

    if not session_id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    waiting_tool_file(session_id).write_text(event.get("tool_name", ""))
    record_session_state(session_id, "decision")


def record_tool_finished(event: dict) -> None:
    """
    Mark the session busy once a tool finishes, unless another tool's prompt still waits.

    Parallel tool calls let a sibling finish while a prompt is up, so only the
    waiting tool's own result ends the decision. Its name stands in for the
    call, since its input can change once answered (e.g. `AskUserQuestion`).

    :param event: PostToolUse or PostToolUseFailure payload naming the tool.
    """
    session_id = event.get("session_id", "")

    try:
        waiting_tool = waiting_tool_file(session_id).read_text()
    except OSError:
        record_session_state(session_id, "busy")
        return

    if waiting_tool != event.get("tool_name", ""):
        return

    waiting_tool_file(session_id).unlink(missing_ok=True)
    record_session_state(session_id, "busy")


def record_turn_state(session_id: str, state: str) -> None:
    """
    Record a state that ends any prompt the session was waiting on.

    :param session_id: Claude session id the state is filed under.
    :param state: "busy" on a new prompt, "ready" once the turn ends.
    """
    if not session_id:
        return

    waiting_tool_file(session_id).unlink(missing_ok=True)
    record_session_state(session_id, state)


def stop_blocked_file(session_id: str) -> Path:
    """
    Returns the file fingerprinting the last stop a sibling Stop hook blocked.

    :param session_id: Claude session id the record is filed under.
    :return: Path beside the session's `.state` record.
    """
    return STATE_DIR / f"{session_id}.stop_blocked"


def session_lock_file(session_id: str) -> Path:
    """
    Returns the file the session's state writes lock on.

    :param session_id: Claude session id the lock is filed under.
    :return: Path beside the session's `.state` record.
    """
    return STATE_DIR / f"{session_id}.lock"


@contextmanager
def session_lock(session_id: str) -> Generator[None]:
    """
    Hold the session's lock, so Stop hooks running in parallel can't interleave their state writes.

    :param session_id: Claude session id whose lock to hold.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    with open(session_lock_file(session_id), "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def stop_fingerprint(event: dict) -> str:
    """
    Returns a fingerprint of the stop, the same for every Stop hook that sees it.

    :param event: Stop hook payload, which each parallel Stop hook receives unchanged.
    :return: Hex digest of the stopping message.
    """
    return hashlib.sha256((event.get("last_assistant_message") or "").encode()).hexdigest()


def record_stop(event: dict) -> None:
    """
    Mark the session ready once its turn ends, unless a sibling Stop hook blocked this stop.

    :param event: Stop hook payload.
    """
    session_id = event.get("session_id", "")

    if not session_id:
        return

    with session_lock(session_id):
        try:
            blocked = stop_blocked_file(session_id).read_text()
        except OSError:
            blocked = ""

        if blocked == stop_fingerprint(event):
            return

        record_turn_state(session_id, "ready")


def record_stop_blocked(event: dict) -> None:
    """
    Mark the session busy again when a Stop hook sends Claude back to work.

    The blocking hooks call this themselves (event "StopBlocked"), since no
    event fires when Claude resumes. The fingerprint stops this session's own
    Stop handler, running in parallel, from writing "ready" after it.

    :param event: The Stop hook payload the blocking hook received.
    """
    session_id = event.get("session_id", "")

    if not session_id:
        return

    with session_lock(session_id):
        stop_blocked_file(session_id).write_text(stop_fingerprint(event))
        record_session_state(session_id, "busy")


def forget_session(session_id: str) -> None:
    """
    Delete the session's state and window records, so its page dot goes back to no session.

    :param session_id: Claude session id whose records to delete.
    """
    if not session_id:
        return

    session_state_file(session_id).unlink(missing_ok=True)
    waiting_tool_file(session_id).unlink(missing_ok=True)
    stop_blocked_file(session_id).unlink(missing_ok=True)
    session_lock_file(session_id).unlink(missing_ok=True)
    window_file(session_id).unlink(missing_ok=True)


def capture_window_id(session_id: str) -> None:
    """
    Record the frontmost window at session launch.

    Terminal.app yields a bare window id. Hammerspoon yields the window id and
    the owning app's bundle id, space-separated, so the raise can fall back to
    activating the app when the window has slipped behind another tab.

    :param session_id: Claude session id the record is filed under.
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
            """
            local window = hs.window.focusedWindow()
            if window == nil or window:id() == nil then
                return ""
            end
            return string.format("%d %s", window:id(), window:application():bundleID() or "")
            """,
            "capture window id",
            session_id,
        )

        if not record:
            log(f"no focused window at launch; cannot record one for session {session_id}")
            return

    window_file(session_id).write_text(record)
    log(f"captured window {record} for session {session_id}")


def focus_window(session_id: str) -> None:
    """
    Force the recorded window to the frontmost layer.

    :param session_id: Claude session id whose window record to raise.
    """
    path = window_file(session_id)

    if not path.exists():
        log(f"no window id on file for session {session_id}; cannot raise (was SessionStart blocked?)")
        return

    record = path.read_text().strip().split()

    if not record:
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
        f"""
        local focused = hs.window.focusedWindow()
        if focused ~= nil and focused:application():bundleID() == "{bundle_id}" then
            return "{bundle_id} is frontmost (typing?); window {window_id} left alone"
        end
        local window = hs.window.get({window_id})
        if window ~= nil then
            window:focus()
            return "raised window {window_id}"
        end
        local app = hs.application.get("{bundle_id}")
        if app == nil then
            return "window {window_id} gone and app {bundle_id} not running; nothing raised"
        end
        app:activate()
        return "window {window_id} not visible (background tab?); activated {bundle_id} instead"
        """,
        f"raise window {window_id}",
        session_id,
    )

    if outcome:
        log(outcome)


def notify(message: str, session_id: str) -> None:
    """
    Fire a native desktop notification with the Glass sound.

    :param message: Notification body (e.g. the hook payload's message).
    :param session_id: Claude session id whose objective titles the notification.
    """
    script = f'display notification "{applescript_quote(message)}" with title "{applescript_quote(objective(session_id))}" sound name "Glass"'

    result = run_osascript(script, "post notification")

    if result.returncode == 0:
        log("notification dispatched; if invisible, allow Script Editor in System Settings > Notifications")


def on_waiting(event: dict) -> None:
    """React to a wait-state: title, Dock bounce, notification, focus."""
    session_id = event.get("session_id", "")
    set_title("READY", session_id)

    # Emit the bell straight to the terminal to bounce the Dock icon.
    write_to_own_tab("\a")

    message = event.get("message") or "Awaiting your approval"
    notify(message, session_id)
    focus_window(session_id)


def record_notification_state(event: dict) -> None:
    """
    Record the state a notification puts the session in, by its `notification_type`.

    A prompt the user has to answer is a decision; the idle notice only means
    the turn is over. Other notifications (e.g. "auth_success") leave the state alone.

    :param event: Notification hook payload.
    """
    session_id = event.get("session_id", "")
    state = NOTIFICATION_STATES.get(event.get("notification_type", ""))

    if state is None:
        return
    elif state == "ready":
        record_turn_state(session_id, state)
        return

    record_session_state(session_id, state)


def main() -> None:
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    session_id = event.get("session_id", "")

    if event_name == "SessionStart":
        log(f"SessionStart: objective={objective(session_id)!r}")
        capture_window_id(session_id)
        set_title("RUNNING", session_id)
        # Skip a compaction's restart, which can land mid-turn while the session is still busy.
        if event.get("source") != "compact":
            record_session_state(session_id, "ready")
    elif event_name == "Notification":
        log(
            "Notification: objective={!r} type={!r} message={!r}".format(
                objective(session_id), event.get("notification_type"), event.get("message")
            )
        )
        record_notification_state(event)
        on_waiting(event)
    elif event_name == "PermissionRequest":
        record_waiting_tool(event)
    elif event_name == "PreToolUse":
        # Mark a tool that waits on the user's answer (wired by matcher in settings.json).
        record_waiting_tool(event)
    elif event_name == "PostToolUse":
        set_title("RUNNING", session_id)
        record_tool_finished(event)
    elif event_name == "PostToolUseFailure":
        record_tool_finished(event)
    elif event_name == "SessionEnd":
        forget_session(session_id)
    elif event_name == "Stop":
        record_stop(event)
    elif event_name == "StopBlocked":
        record_stop_blocked(event)
    elif event_name == "UserPromptSubmit":
        record_turn_state(session_id, "busy")


if __name__ == "__main__":
    main()
