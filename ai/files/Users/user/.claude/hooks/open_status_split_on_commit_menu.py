#!/usr/bin/env python3
"""
Open a shell tab running `git status` beside the session when a commit menu shows.

The session's window keeps claude in its first tab and a shell in an optional
second tab, where `s` and `d` review what a commit menu offers to bank. When a
reply renders a commit menu and that second tab is missing, this opens it, as
Cmd+T would, and types `s` into it. A window that already has a second tab is
left alone, so the shell there keeps whatever the user was running.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the id of Ghostty's front window, the one the session
                  launched in; Ghostty's AppleScript has no tty to match on.
  Stop         -> on a reply carrying commit subject drafts (`[c1]`), count
                  that window's tabs and open the second one if missing.

The tab opens in the directory `report_cwd_for_new_tabs.py` reports for new
tabs (the repo the session last worked in), so `s` reads the worktree rather
than wherever claude launched.

Ghostty only: other emulators lack the scripting to count and open tabs. A
missing window record or osascript failure must never break Claude, so each
fails soft and is recorded to a log instead:

  tail -f /tmp/claude-state-hook/open_status_tab.log
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from report_cwd_for_new_tabs import tab_dir
from terminal_tty import STATE_DIR
from terminal_tty import append_log

LOG_FILE = STATE_DIR / "open_status_tab.log"

# Match the commit row's subject drafts (`[c1]`), which a commit menu renders only over a dirty tree.
COMMIT_DRAFT = re.compile(r"`\[c\d+\]`")

# Type the `git status` alias into the new tab's interactive shell, where dot-star defines it.
STATUS_INPUT = "s\n"


def log(message: str) -> None:
    """Append a timestamped diagnostic line so soft failures stay visible."""
    append_log(LOG_FILE, message)


def window_file(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.ghostty_window"


def run_osascript(script: str, args: list[str], action: str) -> str | None:
    """
    Run an AppleScript `on run argv` handler, returning its result or None on failure.

    :param script: AppleScript source; `args` arrive as `argv`, so nothing needs escaping.
    :param args: Values handed to the script's `argv`.
    :param action: Short label for the log line (e.g. "count tabs").
    :return: The script's result, stripped, or None when osascript failed.
    """
    result = subprocess.run(
        ["osascript", "-", *args],
        input=script,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        log(f"{action} failed (osascript exit {result.returncode}): {result.stderr.strip()}")
        return None

    return result.stdout.strip()


def record_window(session_id: str) -> None:
    """
    Record the id of Ghostty's front window, the one the session launched in.

    :param session_id: Claude session id the record is filed under.
    """
    window_id = run_osascript(
        """
        on run argv
            tell application "Ghostty" to get id of front window
        end run
        """,
        [],
        "capture window id",
    )

    if not window_id:
        return

    window_file(session_id).write_text(window_id)
    log(f"captured window {window_id} for session {session_id}")


def open_status_split(event: dict[str, Any]) -> None:
    """
    Open the session window's second tab running `git status`, unless it already has one.

    :param event: Stop payload parsed from stdin JSON, so its values are untyped (e.g. `{"session_id": "...", "last_assistant_message": "..."}`).
    """
    if not COMMIT_DRAFT.search(event.get("last_assistant_message") or ""):
        return

    session_id = event.get("session_id", "")
    path = window_file(session_id)

    if not path.exists():
        log(f"no window id on file for session {session_id}; cannot open status tab (was SessionStart blocked?)")
        return

    directory = tab_dir(event) or os.path.expanduser("~")
    outcome = run_osascript(
        """
        on run argv
            set windowId to item 1 of argv
            tell application "Ghostty"
                set targetWindows to (every window whose id is windowId)
                if (count of targetWindows) is 0 then
                    return "window " & windowId & " gone; nothing opened"
                end if
                set targetWindow to item 1 of targetWindows
                if (count of tabs of targetWindow) > 1 then
                    return "window " & windowId & " already has a second tab; left alone"
                end if
                set surfaceConfig to new surface configuration
                set initial working directory of surfaceConfig to item 2 of argv
                set initial input of surfaceConfig to item 3 of argv
                new tab in targetWindow with configuration surfaceConfig
                return "opened status tab in window " & windowId
            end tell
        end run
        """,
        [path.read_text().strip(), directory, STATUS_INPUT],
        "open status tab",
    )

    if outcome:
        log(outcome)


def main() -> None:
    if os.environ.get("TERM_PROGRAM") != "ghostty":
        return

    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event: dict[str, Any] = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    if event_name == "SessionStart":
        record_window(event.get("session_id", ""))
    elif event_name == "Stop":
        open_status_split(event)


if __name__ == "__main__":
    main()
