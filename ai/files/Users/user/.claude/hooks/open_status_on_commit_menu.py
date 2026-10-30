#!/usr/bin/env python3
"""
Open a shell listing the staged files beside the session when a commit menu shows.

The session's window keeps claude in its first tab, top pane, and a shell in an
optional second view, where `s` and `d` review what a commit menu offers to bank.
When a reply renders a commit menu and that second view is missing, this opens it
and lists the staged files in it, leaving focus on claude. `STATUS_VIEW` picks
the view:

  "split" -> a pane split off below claude's, as Cmd+Shift+D would, sized to
             the listing plus its prompt and capped at half the tab. Left alone
             when claude's tab already has a second pane.
  "tab"   -> a background tab, as Cmd+T would, after which the tab selected
             before is reselected. Left alone when the window already has a
             second tab.

Ghostty can't split at a given size or report a pane's rows, so the split mode
nudges the divider and re-reads claude's own tty until the top pane leaves the
right number of rows below it.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the id of Ghostty's front window, the one the session
                  launched in; Ghostty's AppleScript has no tty to match on.
  Stop         -> on a reply carrying commit subject drafts (`[c1]`), open the
                  second view if missing.

The view opens in the directory `report_cwd_for_new_tabs.py` reports for new
tabs (the repo the session last worked in), so `s` reads the worktree rather
than wherever claude launched.

Ghostty only: other emulators lack the scripting to count and open panes or
tabs. A missing window record or osascript failure must never break Claude, so
each fails soft and is recorded to a log instead:

  tail -f /tmp/claude-state-hook/open_status.log
"""

import json
import math
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from report_cwd_for_new_tabs import tab_dir
from terminal_tty import STATE_DIR
from terminal_tty import append_log
from terminal_tty import controlling_tty

LOG_FILE = STATE_DIR / "open_status.log"

# Pick where the listing opens: "split" keeps it in view under claude, "tab" keeps claude's pane full height.
STATUS_VIEW = "tab"

# Match the commit row's subject drafts (`[c1]`), which a commit menu renders only over a dirty tree.
COMMIT_DRAFT = re.compile(r"`\[c\d+\]`")

# List what the commit would bank, one path per line, so a split pane stays a few rows tall.
STAGED_COMMAND = ["git", "diff", "--cached", "--name-status"]

# Clear the first-prompt `s` (tools/zsh/.aliases.sh) so the view holds only the listing and its prompt.
STAGED_INPUT = "clear; " + shlex.join(STAGED_COMMAND) + "\n"

# Leave a row for the prompt under the listing; dot-star's zsh prompt is one line.
PROMPT_ROWS = 1

# Count the row Ghostty's split divider takes out of the tab (measured: top + bottom = tab - 1).
DIVIDER_ROWS = 1

# Open the first nudge at the resize units one row took at the usual font size; later nudges re-derive it.
RESIZE_UNITS_PER_ROW_GUESS = 25

# Stop nudging after a few tries, so a pane that won't settle never stalls the Stop hook.
MAX_RESIZE_STEPS = 4

# Wait this long for a pane to take its new size; Ghostty applies a resize within a frame or two.
RESIZE_SETTLE_SECONDS = 0.5

# Mark the split script's success result, followed by the new pane's terminal id.
SPLIT_PREFIX = "split "


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


def staged_listing(directory: str) -> list[str]:
    """
    Returns the lines `STAGED_COMMAND` prints in a directory, or none when git fails there.

    :param directory: Directory the view opens in (e.g. a worktree root).
    :return: One line per staged path (e.g. `"M\\tai/foo.md"`).
    """
    result = subprocess.run(
        STAGED_COMMAND,
        cwd=directory,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        log(f"list staged files failed (git exit {result.returncode}): {result.stderr.strip()}")
        return []

    return result.stdout.splitlines()


def rows_needed(lines: list[str], columns: int) -> int:
    """
    Returns the pane rows that show every line, wrapped at the pane's width, plus the prompt under them.

    :param lines: Lines the pane will print (e.g. `["M\\tai/foo.md"]`).
    :param columns: Pane width in cells, shared with claude's pane since the split runs down.
    :return: Rows the pane needs.
    """
    rows = PROMPT_ROWS

    for line in lines:
        width = len(line.expandtabs())
        rows += max(1, math.ceil(width / columns))

    return rows


def tty_size(tty: str) -> os.terminal_size:
    """
    Returns a tty's current size.

    :param tty: Device path (e.g. "/dev/ttys003").
    :return: The tty's columns and lines.
    """
    descriptor = os.open(tty, os.O_RDONLY | os.O_NOCTTY)

    try:
        return os.get_terminal_size(descriptor)
    finally:
        os.close(descriptor)


def wait_for_rows_change(tty: str, rows: int) -> int:
    """
    Returns a tty's row count once it moves off a known value, or that value after `RESIZE_SETTLE_SECONDS`.

    :param tty: Device path of claude's pane (e.g. "/dev/ttys003").
    :param rows: Row count before the resize (e.g. 35).
    :return: The tty's row count after the wait.
    """
    deadline = time.monotonic() + RESIZE_SETTLE_SECONDS

    while time.monotonic() < deadline:
        current = tty_size(tty).lines

        if current != rows:
            return current

        time.sleep(0.02)

    return rows


def fit_status_pane(terminal_id: str, tty: str, top_rows: int, top_rows_wanted: int) -> None:
    """
    Nudge the split divider until claude's pane is a target height, leaving the rest to the status pane.

    Each nudge re-derives the resize units per row from the rows the last one moved,
    since Ghostty's unit is points and a row's height follows the font size.

    :param terminal_id: Ghostty id of the status pane, whose divider the nudge moves.
    :param tty: Device path of claude's pane, whose rows track the divider.
    :param top_rows: Rows claude's pane has now (e.g. 17).
    :param top_rows_wanted: Rows claude's pane should keep (e.g. 30).
    """
    units_per_row: float = RESIZE_UNITS_PER_ROW_GUESS

    for _ in range(MAX_RESIZE_STEPS):
        rows_off = top_rows_wanted - top_rows

        if rows_off == 0:
            return

        # Move the divider down to grow claude's pane, up to shrink it.
        direction = "down" if rows_off > 0 else "up"
        units = max(1, round(abs(rows_off) * units_per_row))
        outcome = run_osascript(
            """
            on run argv
                tell application "Ghostty" to perform action (item 2 of argv) on terminal id (item 1 of argv)
            end run
            """,
            [terminal_id, f"resize_split:{direction},{units}"],
            "resize status pane",
        )

        if outcome is None:
            return

        moved_to = wait_for_rows_change(tty, top_rows)

        if moved_to == top_rows:
            log(f"resize_split:{direction},{units} moved no rows; status pane left at {top_rows} rows above it")
            return

        units_per_row = units / abs(moved_to - top_rows)
        top_rows = moved_to

    log(f"status pane still {top_rows_wanted - top_rows} rows off after {MAX_RESIZE_STEPS} nudges")


def open_status_split(window_id: str, directory: str, staged: list[str]) -> None:
    """
    Split a pane listing the staged files below claude's, unless claude's tab already has a second pane.

    :param window_id: Ghostty id of the session's window.
    :param directory: Directory the pane opens in (e.g. a worktree root).
    :param staged: Lines `STAGED_COMMAND` printed there (e.g. `["M\\tai/foo.md"]`).
    """
    tty = controlling_tty()

    # Read the tab's size while claude's pane still fills it.
    tab = tty_size(tty) if tty else None

    # Type nothing when nothing is staged, so the pane keeps the first-prompt `s` at half height.
    initial_input = STAGED_INPUT if staged else ""
    outcome = run_osascript(
        """
        on run argv
            set windowId to item 1 of argv
            tell application "Ghostty"
                set targetWindows to (every window whose id is windowId)
                if (count of targetWindows) is 0 then
                    return "window " & windowId & " gone; nothing opened"
                end if
                set claudeTab to tab 1 of item 1 of targetWindows
                if (count of terminals of claudeTab) > 1 then
                    return "window " & windowId & " already has a second pane; left alone"
                end if
                set surfaceConfig to new surface configuration
                set initial working directory of surfaceConfig to item 2 of argv
                if item 3 of argv is not "" then
                    set initial input of surfaceConfig to item 3 of argv
                end if
                set statusTerminal to split (terminal 1 of claudeTab) direction down with configuration surfaceConfig
                -- Even out the panes, as the Cmd+Shift+D keybind's chained action does.
                perform action "equalize_splits" on statusTerminal
                -- Hand focus back to claude's pane, which the split took it from.
                perform action "goto_split:up" on statusTerminal
                return "split " & (id of statusTerminal)
            end tell
        end run
        """,
        [window_id, directory, initial_input],
        "split status pane",
    )

    if not outcome:
        return
    elif not outcome.startswith(SPLIT_PREFIX):
        log(outcome)
        return

    terminal_id = outcome.removeprefix(SPLIT_PREFIX)
    log(f"split status pane {terminal_id} in window {window_id}")

    if not staged:
        return
    elif tty is None or tab is None:
        log("no tty for claude's pane; status pane left at half height")
        return

    # Fit the pane to the listing, never past the half height the split opened at.
    status_rows = min(rows_needed(staged, tab.columns), (tab.lines - DIVIDER_ROWS) // 2)
    top_rows = wait_for_rows_change(tty, tab.lines)
    fit_status_pane(terminal_id, tty, top_rows, tab.lines - DIVIDER_ROWS - status_rows)


def open_status_tab(window_id: str, directory: str, staged: list[str]) -> None:
    """
    Open a background tab listing the staged files, unless the session window already has a second tab.

    :param window_id: Ghostty id of the session's window.
    :param directory: Directory the tab opens in (e.g. a worktree root).
    :param staged: Lines `STAGED_COMMAND` printed there (e.g. `["M\\tai/foo.md"]`).
    """
    # Type nothing when nothing is staged, so the tab keeps the first-prompt `s`.
    initial_input = STAGED_INPUT if staged else ""
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
                set previousTab to selected tab of targetWindow
                set surfaceConfig to new surface configuration
                set initial working directory of surfaceConfig to item 2 of argv
                if item 3 of argv is not "" then
                    set initial input of surfaceConfig to item 3 of argv
                end if
                set statusTab to new tab in targetWindow with configuration surfaceConfig
                -- Hand focus back to the tab the new one took it from.
                select tab previousTab
                return "opened background status tab " & (id of statusTab) & " in window " & windowId
            end tell
        end run
        """,
        [window_id, directory, initial_input],
        "open status tab",
    )

    if outcome:
        log(outcome)


def open_status_view(event: dict[str, Any]) -> None:
    """
    Open the `STATUS_VIEW` listing the staged files when the reply renders a commit menu.

    :param event: Stop payload parsed from stdin JSON, so its values are untyped (e.g. `{"session_id": "...", "last_assistant_message": "..."}`).
    """
    if not COMMIT_DRAFT.search(event.get("last_assistant_message") or ""):
        return

    session_id = event.get("session_id", "")
    path = window_file(session_id)

    if not path.exists():
        log(f"no window id on file for session {session_id}; cannot open status view (was SessionStart blocked?)")
        return

    window_id = path.read_text().strip()
    directory = tab_dir(event) or os.path.expanduser("~")
    staged = staged_listing(directory)

    if STATUS_VIEW == "split":
        open_status_split(window_id, directory, staged)
    elif STATUS_VIEW == "tab":
        open_status_tab(window_id, directory, staged)
    else:
        log(f"unknown STATUS_VIEW {STATUS_VIEW!r}; nothing opened")


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
        open_status_view(event)


if __name__ == "__main__":
    main()
