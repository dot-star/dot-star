"""
Capture and raise the session's terminal window for `announce_window_state.py`.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

from dataclasses import dataclass

from announce_window_state_models import Session
from announce_window_state_scripting import log
from announce_window_state_scripting import lua_quote
from announce_window_state_scripting import run_hammerspoon
from announce_window_state_scripting import run_osascript
from terminal_tty import IN_TERMINAL_APP


@dataclass(frozen=True)
class Window:
    """A terminal window captured at session launch, as Terminal.app or Hammerspoon identifies it."""

    id: str
    bundle_id: str

    def lua_args(self) -> str:
        """
        Returns the window as the leading Lua arguments `notify_claude_session_windows` functions take.

        :return: Window id, then the bundle id as a Lua string literal.
        """
        return f"{self.id}, {lua_quote(self.bundle_id)}"

    def raise_lua(self) -> str:
        """
        Returns Lua statements that focus the window, falling back to activating its app.

        :return: Lua source whose `return` reports what got raised.
        """
        return f"""
        return require("notify_claude_session_windows").raise({self.lua_args()})
        """


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


def recorded_window(session: Session) -> Window | None:
    """
    Returns the window recorded for the session at launch.

    :param session: Claude session whose window record to read.
    :return: The window, with an empty bundle id under Terminal.app, or None
        when no record is on file or the record is empty.
    """
    path = session.window_file

    if not path.exists():
        return None

    fields = path.read_text().strip().split()

    if not fields:
        return None

    return Window(id=fields[0], bundle_id=fields[1] if len(fields) > 1 else "")


def focus_window(session: Session) -> None:
    """
    Force the recorded window to the frontmost layer.

    :param session: Claude session whose window record to raise.
    """
    if not session.window_file.exists():
        log(f"no window id on file for session {session.id}; cannot raise (was SessionStart blocked?)")
        return

    window = recorded_window(session=session)

    if window is None:
        return

    window_id = window.id

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

    bundle_id = window.bundle_id
    outcome = run_hammerspoon(
        lua=f"""
        local focused = hs.window.focusedWindow()
        if focused ~= nil and focused:application():bundleID() == "{bundle_id}" then
            return "{bundle_id} is frontmost (typing?); window {window_id} left alone"
        end
        {window.raise_lua()}
        """,
        action=f"raise window {window_id}",
        session=session,
    )

    if outcome:
        log(outcome)
