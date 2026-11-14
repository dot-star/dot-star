"""
Name the records `announce_window_state.py` files under each Claude session.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

from dataclasses import dataclass
from pathlib import Path

from terminal_tty import STATE_DIR


@dataclass(frozen=True)
class Session:
    """A Claude session's id and the records filed under it in `STATE_DIR`."""

    id: str

    def record_file(self, suffix: str) -> Path:
        """
        Returns the session's record file with the given suffix.

        :param suffix: Extension naming the record (e.g. "state").
        :return: Path under `STATE_DIR` named for the session id.
        """
        return STATE_DIR / f"{self.id}.{suffix}"

    @property
    def hammerspoon_alerted_file(self) -> Path:
        """Returns the marker that the Hammerspoon-unreachable alert already fired."""
        return self.record_file(suffix="hammerspoon_alerted")

    @property
    def lock_file(self) -> Path:
        """Returns the file the session's state writes lock on."""
        return self.record_file(suffix="lock")

    @property
    def notified_file(self) -> Path:
        """Returns the marker that Hammerspoon posted a notification for the session."""
        return self.record_file(suffix="notified")

    @property
    def state_file(self) -> Path:
        """Returns the file holding the session's state word for Hammerspoon's page dots."""
        return self.record_file(suffix="state")

    @property
    def stop_blocked_file(self) -> Path:
        """Returns the file fingerprinting the last stop a sibling Stop hook blocked."""
        return self.record_file(suffix="stop_blocked")

    @property
    def waiting_tool_file(self) -> Path:
        """Returns the file naming the tool whose prompt waits on the user."""
        return self.record_file(suffix="waiting_tool")

    @property
    def window_file(self) -> Path:
        """Returns the file holding the window captured at session launch."""
        return self.record_file(suffix="window")
