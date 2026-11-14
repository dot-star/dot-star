"""
Record each session's state word (busy, decision or ready) for `announce_window_state.py`, which Hammerspoon's page dots read.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

import fcntl
import hashlib
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any

from announce_window_state_models import Session
from announce_window_state_notifications import withdraw_notification
from terminal_tty import STATE_DIR

# Map each notification type to the session state it signals; leave the rest (e.g. "auth_success") unmapped.
NOTIFICATION_STATES = {
    "elicitation_dialog": "decision",
    "elicitation_url_dialog": "decision",
    "idle_prompt": "ready",
    "permission_prompt": "decision",
}


def record_session_state(
    session: Session,
    state: str,
) -> None:
    """
    Record the session's state word for Hammerspoon's page dots to read.

    Writes through a temp file and a rename, so the folder watcher never reads
    a half-written word. Skips the write when the file already holds the word,
    since every write sets off a full page-dots refresh in Hammerspoon.

    :param session: Claude session the state is filed under.
    :param state: One of "busy", "decision" or "ready".
    """
    if not session.id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = session.state_file

    try:
        recorded = path.read_text()
    except OSError:
        recorded = None

    if recorded == state:
        return

    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_text(state)
    temporary.replace(path)

    if state != "decision":
        withdraw_notification(session=session)


def record_waiting_tool(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session as waiting on the user to answer a prompt for the event's tool.

    :param session: Claude session the record is filed under.
    :param event: PermissionRequest or PreToolUse payload naming the tool.
    """
    if not session.id:
        return

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    session.waiting_tool_file.write_text(event.get("tool_name", ""))
    record_session_state(session=session, state="decision")


def record_tool_finished(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session busy once a tool finishes, unless another tool's prompt still waits.

    Parallel tool calls let a sibling finish while a prompt is up, so only the
    waiting tool's own result ends the decision. Its name stands in for the
    call, since its input can change once answered (e.g. `AskUserQuestion`).

    :param session: Claude session the record is filed under.
    :param event: PostToolUse or PostToolUseFailure payload naming the tool.
    """
    try:
        waiting_tool = session.waiting_tool_file.read_text()
    except OSError:
        record_session_state(session=session, state="busy")
        return

    if waiting_tool != event.get("tool_name", ""):
        return

    session.waiting_tool_file.unlink(missing_ok=True)
    record_session_state(session=session, state="busy")


def record_turn_state(
    session: Session,
    state: str,
) -> None:
    """
    Record a state that ends any prompt the session was waiting on.

    :param session: Claude session the state is filed under.
    :param state: "busy" on a new prompt, "ready" once the turn ends.
    """
    if not session.id:
        return

    session.waiting_tool_file.unlink(missing_ok=True)
    record_session_state(session=session, state=state)


@contextmanager
def session_lock(session: Session) -> Generator[None]:
    """
    Hold the session's lock, so Stop hooks running in parallel can't interleave their state writes.

    :param session: Claude session whose lock to hold.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    with open(session.lock_file, "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def stop_fingerprint(event: dict[str, Any]) -> str:
    """
    Returns a fingerprint of the stop, the same for every Stop hook that sees it.

    :param event: Stop hook payload, which each parallel Stop hook receives unchanged.
    :return: Hex digest of the stopping message.
    """
    return hashlib.sha256((event.get("last_assistant_message") or "").encode()).hexdigest()


def record_stop(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session ready once its turn ends, unless a sibling Stop hook blocked this stop.

    :param session: Claude session the state is filed under.
    :param event: Stop hook payload.
    """
    if not session.id:
        return

    with session_lock(session=session):
        try:
            blocked = session.stop_blocked_file.read_text()
        except OSError:
            blocked = ""

        if blocked == stop_fingerprint(event=event):
            return

        record_turn_state(session=session, state="ready")


def record_stop_blocked(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Mark the session busy again when a Stop hook sends Claude back to work.

    The blocking hooks call this themselves (event "StopBlocked"), since no
    event fires when Claude resumes. The fingerprint stops this session's own
    Stop handler, running in parallel, from writing "ready" after it.

    :param session: Claude session the state is filed under.
    :param event: The Stop hook payload the blocking hook received.
    """
    if not session.id:
        return

    with session_lock(session=session):
        session.stop_blocked_file.write_text(stop_fingerprint(event=event))
        record_session_state(session=session, state="busy")


def forget_session(session: Session) -> None:
    """
    Delete the session's state and window records, so its page dot goes back to no session.

    :param session: Claude session whose records to delete.
    """
    if not session.id:
        return

    withdraw_notification(session=session)
    session.state_file.unlink(missing_ok=True)
    session.waiting_tool_file.unlink(missing_ok=True)
    session.stop_blocked_file.unlink(missing_ok=True)
    session.lock_file.unlink(missing_ok=True)
    session.window_file.unlink(missing_ok=True)


def record_notification_state(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    Record the state a notification puts the session in, by its `notification_type`.

    A prompt the user has to answer is a decision; the idle notice only means
    the turn is over. Other notifications (e.g. "auth_success") leave the state alone.

    :param session: Claude session the state is filed under.
    :param event: Notification hook payload.
    """
    state = NOTIFICATION_STATES.get(event.get("notification_type", ""))

    if state is None:
        return
    elif state == "ready":
        record_turn_state(session=session, state=state)
        return

    record_session_state(session=session, state=state)
