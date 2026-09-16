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
instead. Tail it while debugging "nothing happened":

  tail -f /tmp/claude-state-hook/announce_window_state.log
"""

import json
import os
import subprocess
import sys
from pathlib import Path

from claude_session_dir import claude_session_dir
from terminal_tty import IN_TERMINAL_APP, STATE_DIR, append_log, controlling_tty, write_to_terminal

LOG_FILE = STATE_DIR / "announce_window_state.log"
WINDOW_OBJECTIVE = os.environ.get("CLAUDE_OBJECTIVE", "Claude Code")

# Reach Hammerspoon through the client shipped inside its bundle rather than a
# PATH lookup, since hooks run with claude's environment, not the login shell's.
HAMMERSPOON_CLI = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"


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


def run_hammerspoon(lua: str, action: str) -> str | None:
    """
    Run a Lua snippet inside Hammerspoon, returning its printed result or None on failure.

    :param lua: Lua source for `hs -c`; its `return` value comes back as text.
    :param action: Short label for the log line (e.g. "capture window id").
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


def state_file(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.window"


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
        )

        if not record:
            log(f"no focused window at launch; cannot record one for session {session_id}")
            return

    state_file(session_id).write_text(record)
    log(f"captured window {record} for session {session_id}")


def focus_window(session_id: str) -> None:
    """
    Force the recorded window to the frontmost layer.

    :param session_id: Claude session id whose window record to raise.
    """
    path = state_file(session_id)

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
    elif event_name == "Notification":
        log("Notification: objective={!r} message={!r}".format(objective(session_id), event.get("message")))
        on_waiting(event)
    elif event_name == "PostToolUse":
        set_title("RUNNING", session_id)


if __name__ == "__main__":
    main()
