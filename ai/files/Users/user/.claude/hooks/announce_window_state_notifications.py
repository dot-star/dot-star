"""
Post and withdraw the desktop notification `announce_window_state.py` raises while a session waits on the user.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

from announce_window_state_models import Session
from announce_window_state_scripting import applescript_quote
from announce_window_state_scripting import log
from announce_window_state_scripting import lua_quote
from announce_window_state_scripting import run_hammerspoon
from announce_window_state_scripting import run_osascript
from announce_window_state_title import objective
from announce_window_state_windows import recorded_window
from terminal_tty import IN_TERMINAL_APP


def withdraw_notification(session: Session) -> None:
    """
    Withdraw the session's Hammerspoon notification once nothing waits on the user.

    Skips the Hammerspoon call unless a notification was posted, since the
    state changes on every turn. An `osascript` notification can't be
    withdrawn, so a Terminal.app session never records one.

    :param session: Claude session whose notification to withdraw.
    """
    marker = session.notified_file

    if not marker.exists():
        return

    marker.unlink(missing_ok=True)
    record = recorded_window(session=session)

    if not record:
        return

    window_id = record[0]
    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        return require("notify_claude_session_windows").withdraw({window_id}, {lua_quote(bundle_id)})
        """,
        action="withdraw notification",
        session=session,
    )

    if outcome:
        log(outcome)


def post_osascript_notification(
    message: str,
    title: str,
) -> None:
    """
    Post a notification through `osascript`, which macOS files under Script Editor.

    :param message: Notification body (e.g. the hook payload's message).
    :param title: Notification title (e.g. the session's objective).
    """
    script = f'display notification "{applescript_quote(message)}" with title "{applescript_quote(title)}"'

    result = run_osascript(script, "post notification")

    if result.returncode == 0:
        log("notification dispatched; if invisible, allow Script Editor in System Settings > Notifications")


def post_clickable_notification(
    message: str,
    title: str,
    session: Session,
) -> bool:
    """
    Post a notification through Hammerspoon that raises the session's window when clicked.

    :param message: Notification body (e.g. the hook payload's message).
    :param title: Notification title (e.g. the session's objective).
    :param session: Claude session whose recorded window the click raises.
    :return: True once Hammerspoon posted it; False when no window is on file
        or Hammerspoon can't be reached, so the caller can fall back.
    """
    record = recorded_window(session=session)

    # Fall back when no window is on file (None) or the record is empty.
    if not record:
        return False

    window_id = record[0]
    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        return require("notify_claude_session_windows").post(
            {window_id},
            {lua_quote(bundle_id)},
            {lua_quote(title)},
            {lua_quote(message)}
        )
        """,
        action="post clickable notification",
        session=session,
    )

    if outcome is None:
        return False

    session.notified_file.write_text("")
    log(outcome)
    return True


def notify(
    message: str,
    session: Session,
) -> None:
    """
    Fire a silent native desktop notification.

    Silent because `chime_when_waiting_on_user_to_answer.sh` already chimes on
    this event, debounced across sessions; a sound here would double it.

    Hammerspoon posts it when it can, since its click callback raises the
    session's window; clicking an `osascript` notification opens Script Editor.

    :param message: Notification body (e.g. the hook payload's message).
    :param session: Claude session whose objective titles the notification.
    """
    title = objective(session=session)

    if IN_TERMINAL_APP:
        post_osascript_notification(message=message, title=title)
        return
    elif post_clickable_notification(message=message, title=title, session=session):
        return

    post_osascript_notification(message=message, title=title)
