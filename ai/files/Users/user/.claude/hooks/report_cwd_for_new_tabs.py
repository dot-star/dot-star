#!/usr/bin/env python3
"""
Report the session's working directory to the terminal so a new tab opens there.

Terminals open a new tab in the directory the current tab last reported through
OSC 7. The shell reports on every prompt, but claude holds the foreground for a
whole session, so the tab keeps whatever the shell reported before launch: a
`cd` inside the session moves claude's cwd and leaves the tab's copy behind.

Wired in settings.json so each event runs this script with the event's JSON
payload on stdin. The payload's `cwd` is claude's current directory, so
reporting it on SessionStart and after every tool that can move it (Bash,
EnterWorktree, ExitWorktree) keeps the tab's copy current. Nothing to undo at
SessionEnd: once claude exits, the shell's next prompt reports the real pwd.

A worktree the session works in wins over `cwd`. A worktree in another repo
can't be entered, so claude's cwd stays at launch while every edit lands in the
worktree; the marker `record_worktree_for_statusline.sh` keeps (from Edit,
Write and `git worktree add`) names it. That hook runs alongside this one, so a
freshly recorded worktree reaches the tab one tool call later.

Emit the sequence the emulator's own shell integration emits, read off
TERM_PROGRAM:

  Terminal.app  -> `file://<host><percent-encoded path>`, the form
                   /etc/zshrc_Apple_Terminal emits.
  anything else -> `kitty-shell-cwd://<host><raw path>`, the form Ghostty's zsh
                   integration emits; the scheme carries the path unencoded.

A failed write must never break Claude, so it fails soft and is recorded to a
log instead. Tail it while debugging "the tab still opens in the old place":

  tail -f /tmp/claude-state-hook/report_cwd.log
"""

import json
import os
import socket
import sys
from urllib.parse import quote

from claude_session_dir import claude_session_dir
from terminal_tty import IN_TERMINAL_APP, STATE_DIR, append_log, controlling_tty, write_to_terminal

LOG_FILE = STATE_DIR / "report_cwd.log"


def log(message: str) -> None:
    """Append a timestamped diagnostic line so soft failures stay visible."""
    append_log(LOG_FILE, message)


def cwd_url(cwd: str) -> str:
    """
    Build the OSC 7 payload URL for a directory.

    :param cwd: Absolute path to report (e.g. "/Users/me/Projects/foo").
    :return: URL in the form the running emulator's shell integration emits.
    """
    host = socket.gethostname()

    if IN_TERMINAL_APP:
        return f"file://{host}{quote(cwd)}"

    return f"kitty-shell-cwd://{host}{cwd}"


def session_worktree(session_id: str) -> str | None:
    """
    Return the worktree the session's marker names, or None when there is none.

    :param session_id: Raw session id from the hook payload (e.g. a uuid).
    :return: The worktree path, or None when the marker is missing or its
        worktree has since been torn down.
    """
    session_dir = claude_session_dir(session_id)

    if session_dir is None:
        return None

    marker = session_dir / "worktree"

    if not marker.is_file():
        return None

    worktree = marker.read_text().strip()

    if not os.path.isdir(worktree):
        return None

    return worktree


def report_cwd(tty: str, cwd: str) -> None:
    """
    Write the OSC 7 sequence for `cwd` straight to the session's tty, logging any failure.

    :param tty: /dev path of the tab to update (e.g. "/dev/ttys003").
    :param cwd: Absolute path to report (e.g. "/Users/me/Projects/foo").
    """
    error = write_to_terminal(tty, f"\033]7;{cwd_url(cwd)}\a")

    if error is not None:
        log(f"report {cwd} failed (write to {tty}): {error}")


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    cwd = session_worktree(event.get("session_id", "")) or event.get("cwd")

    if not cwd:
        log("no cwd on the payload; skipping")
        return

    tty = controlling_tty()

    if tty is None:
        log(f"no controlling tty for ppid {os.getppid()}; skipping")
        return

    report_cwd(tty, cwd)


if __name__ == "__main__":
    main()
