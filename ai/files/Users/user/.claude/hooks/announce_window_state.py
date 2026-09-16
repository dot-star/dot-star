#!/usr/bin/env python3
"""Drive terminal window state from Claude Code hook events.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the front window id, label the tab `[RUNNING]`.
  Notification -> Claude is waiting on you: `[WAITING]` title, Dock bounce,
                  desktop notification, and pull the window frontmost.
  PostToolUse  -> a tool finished (including one you just approved): reset to
                  `[RUNNING]`.

No wrapper process sits in the I/O path. The script reaches the Terminal tab by
writing OSC/bell bytes straight to the claude process's controlling tty, and
focuses the window via the id captured at launch. The per-window objective comes
from CLAUDE_OBJECTIVE (set by `cl --obj "..."`, aliased `clo`).

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
from datetime import datetime
from pathlib import Path

STATE_DIR = Path("/tmp/claude-state-hook")
LOG_FILE = STATE_DIR / "announce_window_state.log"
OBJECTIVE = os.environ.get("CLAUDE_OBJECTIVE", "Claude Code")

# Pick the window mechanism by the emulator claude runs in. Hooks inherit
# claude's environment, and Terminal.app stamps this value on every shell it
# opens.
IN_TERMINAL_APP = os.environ.get("TERM_PROGRAM") == "Apple_Terminal"

# Reach Hammerspoon through the client shipped inside its bundle rather than a
# PATH lookup, since hooks run with claude's environment, not the login shell's.
HAMMERSPOON_CLI = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"


def log(message):
    """Append a timestamped diagnostic line so soft failures stay visible."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with open(LOG_FILE, "a") as handle:
        handle.write("{} {}\n".format(stamp, message))


def applescript_quote(text):
    """Escape a string for safe interpolation into an AppleScript literal."""
    return text.replace("\\", "\\\\").replace('"', '\\"')


def run_osascript(script, action):
    """Run an AppleScript snippet, logging any failure with a permission hint."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        stderr = result.stderr.strip()
        log("{} failed (osascript exit {}): {}".format(action, result.returncode, stderr))
        # -1743 is macOS's "not authorized to send Apple events": Automation is off.
        if "-1743" in stderr or "Not authorized" in stderr:
            log("  fix: System Settings > Privacy & Security > Automation > Terminal > enable Terminal")

    return result


def run_hammerspoon(lua, action):
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
        )
    except OSError as error:
        log("{} failed (no Hammerspoon client at {}): {}".format(action, HAMMERSPOON_CLI, error))
        return None

    if result.returncode != 0:
        log("{} failed (hs exit {}): {}".format(action, result.returncode, result.stderr.strip()))
        log("  fix: Hammerspoon must be running with `require('hs.ipc')` in its init.lua")
        return None

    return result.stdout.strip()


def controlling_tty():
    """Return the /dev path of the Terminal tab that owns the claude process."""
    # The hook's parent ($PPID) shares claude's controlling terminal, inherited
    # across fork and unaffected by the hook's piped stdio. ps reports it
    # abbreviated (e.g. "s003"), so re-expand to a /dev path.
    name = subprocess.check_output(
        ["ps", "-o", "tty=", "-p", str(os.getppid())],
        text=True,
    ).strip()

    if not name or name.startswith("?"):
        return None

    if not name.startswith("tty"):
        name = "tty" + name

    return "/dev/" + name


def write_to_terminal(payload):
    """Send raw bytes straight to the Terminal tab, bypassing the hook pipe."""
    dev = controlling_tty()

    if dev is None:
        log("no controlling tty for ppid {}; title/bell skipped".format(os.getppid()))
        return

    try:
        with open(dev, "w") as terminal:
            terminal.write(payload)
    except OSError as error:
        log("write to {} failed: {}".format(dev, error))


def set_title(state):
    """Set the tab/window title to `[STATE] <Objective>` via an OSC escape."""
    write_to_terminal("\033]0;[{}] {}\007".format(state, OBJECTIVE))


def state_file(session_id):
    return STATE_DIR / "{}.window".format(session_id)


def capture_window_id(session_id):
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
            log("no focused window at launch; cannot record one for session {}".format(session_id))
            return

    state_file(session_id).write_text(record)
    log("captured window {} for session {}".format(record, session_id))


def focus_window(session_id):
    """
    Force the recorded window to the frontmost layer.

    :param session_id: Claude session id whose window record to raise.
    """
    path = state_file(session_id)

    if not path.exists():
        log("no window id on file for session {}; cannot raise (was SessionStart blocked?)".format(session_id))
        return

    record = path.read_text().strip().split()

    if not record:
        return

    window_id = record[0]

    if IN_TERMINAL_APP:
        run_osascript(
            'tell application "Terminal" to set frontmost of window id {} to true'.format(window_id),
            "raise window {}".format(window_id),
        )
        return

    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        """
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
        """.format(window_id=window_id, bundle_id=bundle_id),
        "raise window {}".format(window_id),
    )

    if outcome:
        log(outcome)


def notify(message):
    """Fire a native desktop notification with the Glass sound."""
    script = 'display notification "{body}" with title "{title}" sound name "Glass"'.format(
        body=applescript_quote(message),
        title=applescript_quote(OBJECTIVE),
    )

    result = run_osascript(script, "post notification")

    if result.returncode == 0:
        log("notification dispatched; if invisible, allow Script Editor in System Settings > Notifications")


def on_waiting(event):
    """React to a wait-state: title, Dock bounce, notification, focus."""
    set_title("WAITING")

    # Emit the bell straight to the terminal to bounce the Dock icon.
    write_to_terminal("\a")

    message = event.get("message") or "Awaiting your approval"
    notify(message)
    focus_window(event.get("session_id", ""))


def main():
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    if event_name == "SessionStart":
        log("SessionStart: objective={!r}".format(OBJECTIVE))
        capture_window_id(event.get("session_id", ""))
        set_title("RUNNING")
    elif event_name == "Notification":
        log("Notification: objective={!r} message={!r}".format(OBJECTIVE, event.get("message")))
        on_waiting(event)
    elif event_name == "PostToolUse":
        set_title("RUNNING")


if __name__ == "__main__":
    main()
