"""
Shared plumbing for hooks that write escape sequences to the session's terminal.

Import-only (no shebang, not executable): `announce_window_state.py`,
`color_tab_per_session.py` and `report_cwd_for_new_tabs.py` import it from the
hooks directory, which Python puts on `sys.path` when it runs a script there.

Hooks run with piped stdio, so `/dev/tty` is closed to them; the terminal is
reached through the tty the parent claude process owns, and every write fails
soft so a missing permission never breaks Claude.
"""

import os
import subprocess
from datetime import datetime
from pathlib import Path

STATE_DIR = Path("/tmp/claude-state-hook")

# Gate emulator-specific paths on the emulator claude runs in. Hooks inherit
# claude's environment, and Terminal.app stamps this value on every shell it
# opens.
IN_TERMINAL_APP = os.environ.get("TERM_PROGRAM") == "Apple_Terminal"


def append_log(log_file: Path, message: str) -> None:
    """
    Append a timestamped diagnostic line so soft failures stay visible.

    :param log_file: Path of the hook's own log under `STATE_DIR`.
    :param message: Line to record, without a timestamp or newline.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S")

    with open(log_file, "a") as handle:
        handle.write(f"{stamp} {message}\n")


def controlling_tty() -> str | None:
    """Return the /dev path of the terminal tab that owns the claude process, or None."""
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


def write_to_terminal(tty: str, payload: str) -> OSError | None:
    """
    Write raw bytes straight to the session's tty.

    :param tty: /dev path of the tab to write to (e.g. "/dev/ttys003").
    :param payload: Escape sequence to emit, terminator included.
    :return: The `OSError` when the write failed, so the caller can log it
        under its own action label; None on success.
    """
    try:
        with open(tty, "w") as terminal:
            terminal.write(payload)
    except OSError as error:
        return error

    return None
