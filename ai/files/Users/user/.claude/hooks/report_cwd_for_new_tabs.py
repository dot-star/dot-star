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
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

STATE_DIR = Path("/tmp/claude-state-hook")
LOG_FILE = STATE_DIR / "report_cwd.log"

# Pick the OSC 7 form by the emulator claude runs in. Hooks inherit claude's
# environment, and Terminal.app stamps this value on every shell it opens.
IN_TERMINAL_APP = os.environ.get("TERM_PROGRAM") == "Apple_Terminal"


def log(message):
    """Append a timestamped diagnostic line so soft failures stay visible."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with open(LOG_FILE, "a") as handle:
        handle.write("{} {}\n".format(stamp, message))


def controlling_tty():
    """Return the /dev path of the terminal tab that owns the claude process."""
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
    try:
        with open(tty, "w") as terminal:
            terminal.write("\033]7;{}\a".format(cwd_url(cwd)))
    except OSError as error:
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
