"""
Label the session's terminal tab for `announce_window_state.py`: the `[STATE] <Objective>` title and the bell.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

import os

from announce_window_state_models import Session
from announce_window_state_scripting import log
from claude_session_dir import claude_session_dir
from terminal_tty import controlling_tty
from terminal_tty import write_to_terminal

WINDOW_OBJECTIVE = os.environ.get("CLAUDE_OBJECTIVE", "Claude Code")


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


def objective(session: Session) -> str:
    """
    Returns the objective to label this session's window with.

    Prefers the session's caveman summary marker, which the statusline renders
    too, so the title and the bar name the work the same way. Falls back to the
    window-scoped `WINDOW_OBJECTIVE` before the marker exists (SessionStart, the
    first prompt) or when the session id is missing.

    :param session: Claude session whose marker to read.
    :return: First line of the objective marker, else `WINDOW_OBJECTIVE`.
    """
    session_dir = claude_session_dir(session.id)

    if session_dir is None:
        return WINDOW_OBJECTIVE

    try:
        first_line = (session_dir / "objective").read_text().partition("\n")[0].strip()
    except OSError:
        return WINDOW_OBJECTIVE

    return first_line or WINDOW_OBJECTIVE


def set_title(
    state: str,
    session: Session,
) -> None:
    """
    Set the tab/window title to `[STATE] <Objective>` via an OSC escape.

    :param state: Label for the bracket (e.g. "RUNNING", "READY").
    :param session: Claude session whose objective fills the title.
    """
    write_to_own_tab(f"\033]0;[{state}] {objective(session=session)}\007")
