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

The repo the session last worked in wins over `cwd`. Claude can't enter a
worktree or repo outside the one it launched in, so its cwd stays at launch
while every edit lands elsewhere. `record_worktree_for_statusline.sh` keeps two
markers naming that place: `last_repo` (the repo of the last Edit or Write, or
the last worktree a tool named) first, else `worktree` (a session from before
`last_repo` existed). That hook runs alongside this one, so a freshly recorded
repo reaches the tab one tool call later. Set `TAB_FOLLOWS` to "worktree" to
skip `last_repo` and keep the tab on the session's worktree.

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
from typing import Any
from urllib.parse import quote

from claude_session_dir import claude_session_dir
from terminal_tty import IN_TERMINAL_APP
from terminal_tty import STATE_DIR
from terminal_tty import append_log
from terminal_tty import controlling_tty
from terminal_tty import write_to_terminal

LOG_FILE = STATE_DIR / "report_cwd.log"

# Pick where a new tab opens: "last_repo" follows the last repo edited, "worktree" stays on the session's worktree.
TAB_FOLLOWS = "last_repo"


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


def session_marker(session_id: str, name: str) -> str | None:
    """
    Return the directory a session marker names, or None when there is none.

    :param session_id: Raw session id from the hook payload (e.g. a uuid).
    :param name: Marker file in the session dir (e.g. "worktree").
    :return: The directory path, or None when the marker is missing or its
        directory has since been removed.
    """
    session_dir = claude_session_dir(session_id)

    if session_dir is None:
        return None

    marker = session_dir / name

    if not marker.is_file():
        return None

    directory = marker.read_text().strip()

    if not os.path.isdir(directory):
        return None

    return directory


def report_cwd(tty: str, cwd: str) -> None:
    """
    Write the OSC 7 sequence for `cwd` straight to the session's tty, logging any failure.

    :param tty: /dev path of the tab to update (e.g. "/dev/ttys003").
    :param cwd: Absolute path to report (e.g. "/Users/me/Projects/foo").
    """
    error = write_to_terminal(tty, f"\033]7;{cwd_url(cwd)}\a")

    if error is not None:
        log(f"report {cwd} failed (write to {tty}): {error}")


def tab_dir_following_last_repo(event: dict[str, Any]) -> str | None:
    """
    Return the repo the session last worked in, else its worktree, else claude's cwd.

    :param event: Hook payload parsed from stdin JSON, so its values are untyped (e.g. `{"session_id": "...", "cwd": "/Users/me/foo"}`).
    :return: Directory for a new tab, or None when the payload carries no cwd.
    """
    session_id = event.get("session_id", "")

    return session_marker(session_id, "last_repo") or session_marker(session_id, "worktree") or event.get("cwd")


def tab_dir_following_worktree(event: dict[str, Any]) -> str | None:
    """
    Return the session's worktree, else claude's cwd.

    :param event: Hook payload parsed from stdin JSON, so its values are untyped (e.g. `{"session_id": "...", "cwd": "/Users/me/foo"}`).
    :return: Directory for a new tab, or None when the payload carries no cwd.
    """
    return session_marker(event.get("session_id", ""), "worktree") or event.get("cwd")


def tab_dir(event: dict[str, Any]) -> str | None:
    """
    Return the directory a new tab should open in, per `TAB_FOLLOWS`.

    :param event: Hook payload parsed from stdin JSON, so its values are untyped (e.g. `{"session_id": "...", "cwd": "/Users/me/foo"}`).
    :return: Directory for a new tab, or None when there is none or `TAB_FOLLOWS` is unknown.
    """
    if TAB_FOLLOWS == "last_repo":
        return tab_dir_following_last_repo(event)
    elif TAB_FOLLOWS == "worktree":
        return tab_dir_following_worktree(event)

    log(f"unknown TAB_FOLLOWS {TAB_FOLLOWS!r}; skipping")
    return None


def main() -> None:
    try:
        event: dict[str, Any] = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    cwd = tab_dir(event)

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
