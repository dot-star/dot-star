"""
Capture and raise the session's terminal window for `announce_window_state.py`.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

from announce_window_state_models import Session
from announce_window_state_scripting import log
from announce_window_state_scripting import lua_quote
from announce_window_state_scripting import run_hammerspoon
from announce_window_state_scripting import run_osascript
from terminal_tty import IN_TERMINAL_APP


def capture_window_id(session: Session) -> None:
    """
    Record the frontmost window at session launch.

    Terminal.app yields a bare window id. Hammerspoon yields the window id and
    the owning app's bundle id, space-separated, so the raise can fall back to
    activating the app when the window has slipped behind another tab.

    :param session: Claude session the record is filed under.
    """
    if IN_TERMINAL_APP:
        result = run_osascript(
            'tell application "Terminal" to id of front window',
            "capture window id",
        )

        if result.returncode != 0:
            return

        record = result.stdout.strip()
    else:
        record = run_hammerspoon(
            lua="""
            local window = hs.window.focusedWindow()
            if window == nil or window:id() == nil then
                return ""
            end
            return string.format("%d %s", window:id(), window:application():bundleID() or "")
            """,
            action="capture window id",
            session=session,
        )

        if not record:
            log(f"no focused window at launch; cannot record one for session {session.id}")
            return

    session.window_file.write_text(record)
    log(f"captured window {record} for session {session.id}")


def recorded_window(session: Session) -> list[str] | None:
    """
    Returns the session's window record split into its fields.

    :param session: Claude session whose window record to read.
    :return: Window id, then the owning app's bundle id under Hammerspoon
        (e.g. `["12345", "com.mitchellh.ghostty"]`), or None when no record is on file.
    """
    path = session.window_file

    if not path.exists():
        return None

    return path.read_text().strip().split()


def raise_window_lua(
    window_id: str,
    bundle_id: str,
) -> str:
    """
    Returns Lua statements that focus a window, falling back to activating its app.

    :param window_id: Hammerspoon window id to focus (e.g. "12345").
    :param bundle_id: Bundle id of the app to activate when the window is gone
        or sits in a background tab (e.g. "com.mitchellh.ghostty").
    :return: Lua source whose `return` reports what got raised.
    """
    return f"""
        return require("notify_claude_session_windows").raise({window_id}, {lua_quote(bundle_id)})
        """


def focus_window(session: Session) -> None:
    """
    Force the recorded window to the frontmost layer.

    :param session: Claude session whose window record to raise.
    """
    record = recorded_window(session=session)

    if record is None:
        log(f"no window id on file for session {session.id}; cannot raise (was SessionStart blocked?)")
        return
    elif not record:
        return

    window_id = record[0]

    # Leave focus alone while a window of the session's own terminal app is
    # frontmost: the user may be mid-keystroke in another session, and a raise
    # would redirect their typing. The title, bell and notification still fire.
    if IN_TERMINAL_APP:
        result = run_osascript(
            'tell application "Terminal" to get frontmost',
            "check Terminal focus",
        )

        if result.returncode == 0 and result.stdout.strip() == "true":
            log(f"Terminal is frontmost (typing?); window {window_id} left alone")
            return

        run_osascript(
            f'tell application "Terminal" to set frontmost of window id {window_id} to true',
            f"raise window {window_id}",
        )
        return

    bundle_id = record[1] if len(record) > 1 else ""
    outcome = run_hammerspoon(
        lua=f"""
        local focused = hs.window.focusedWindow()
        if focused ~= nil and focused:application():bundleID() == "{bundle_id}" then
            return "{bundle_id} is frontmost (typing?); window {window_id} left alone"
        end
        {raise_window_lua(window_id=window_id, bundle_id=bundle_id)}
        """,
        action=f"raise window {window_id}",
        session=session,
    )

    if outcome:
        log(outcome)
