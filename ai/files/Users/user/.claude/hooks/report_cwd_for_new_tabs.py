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

from terminal_tty import IN_TERMINAL_APP, STATE_DIR, append_log, controlling_tty, write_to_terminal

LOG_FILE = STATE_DIR / "report_cwd.log"


def log(message):
    """Append a timestamped diagnostic line so soft failures stay visible."""
    append_log(LOG_FILE, message)


def cwd_url(cwd):
    """
    Build the OSC 7 payload URL for a directory.

    :param cwd: Absolute path to report (e.g. "/Users/me/Projects/foo").
    :return: URL in the form the running emulator's shell integration emits.
    """
    host = socket.gethostname()

    if IN_TERMINAL_APP:
        return "file://{}{}".format(host, quote(cwd))

    return "kitty-shell-cwd://{}{}".format(host, cwd)


def report_cwd(tty, cwd):
    """
    Write the OSC 7 sequence for `cwd` straight to the session's tty, logging any failure.

    :param tty: /dev path of the tab to update (e.g. "/dev/ttys003").
    :param cwd: Absolute path to report (e.g. "/Users/me/Projects/foo").
    """
    error = write_to_terminal(tty, "\033]7;{}\a".format(cwd_url(cwd)))

    if error is not None:
        log("report {} failed (write to {}): {}".format(cwd, tty, error))


def main():
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    cwd = event.get("cwd")

    if not cwd:
        log("no cwd on the payload; skipping")
        return

    tty = controlling_tty()

    if tty is None:
        log("no controlling tty for ppid {}; skipping".format(os.getppid()))
        return

    report_cwd(tty, cwd)


if __name__ == "__main__":
    main()
