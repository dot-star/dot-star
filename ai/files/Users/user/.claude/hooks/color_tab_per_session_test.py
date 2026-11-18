#!/usr/bin/env python3
"""
Tests for color_tab_per_session: the tab look a SessionStart saves for SessionEnd to restore.

Stands in for Terminal.app at the osascript boundary (`read_tab`, `apply_profile`,
`apply_background`) and for the tty lookup, so the suite runs without a live tab.
"""

import json
import os
import tempfile
import unittest
from collections.abc import Callable
from pathlib import Path
from typing import Any
from unittest import mock

import color_tab_per_session
from color_tab_per_session import on_session_start

SESSION_ID = "12345678-90ab-cdef-1234-567890abcdef"


def tab_wearing(
    profile: str,
    background: str,
) -> Callable[[str, str], str]:
    """
    Returns a `read_tab` stand-in for a tab showing the given look.

    :param profile: Settings name the tab reports (e.g. "Basic").
    :param background: Background color the tab reports (e.g. "0, 0, 0").
    :return: Function answering each AppleScript property the hook reads.
    """

    def read_tab(
        _tty: str,
        expression: str,
    ) -> str:
        if "settings" in expression:
            return profile

        return background

    return read_tab


class OnSessionStartTest(unittest.TestCase):
    """Test the `on_session_start` function."""

    def setUp(self) -> None:
        session_dir = tempfile.TemporaryDirectory()
        self.addCleanup(session_dir.cleanup)
        self.session_dir = Path(session_dir.name)
        for patcher in [
            mock.patch.dict(os.environ, {"CLAUDE_SESSION_COLOR": "profile,tint"}),
            mock.patch.object(color_tab_per_session, "IN_TERMINAL_APP", True),
            mock.patch.object(color_tab_per_session, "claude_session_dir", return_value=self.session_dir),
            mock.patch.object(color_tab_per_session, "log"),
            # Stand in for Terminal.app, which the hook recolors through osascript.
            mock.patch.object(color_tab_per_session, "apply_profile"),
            mock.patch.object(color_tab_per_session, "apply_background"),
        ]:
            patcher.start()
            self.addCleanup(patcher.stop)

    def start(
        self,
        tty: str,
        profile: str,
        background: str,
    ) -> dict[str, Any]:
        """
        Runs a SessionStart from the given tab and returns the state it saved.

        :param tty: Controlling tty the session runs on (e.g. "/dev/ttys001").
        :param profile: Settings name the tab wears when the hook reads it.
        :param background: Background color the tab wears when the hook reads it.
        :return: The saved state, as SessionEnd will read it.
        """
        with (
            mock.patch.object(color_tab_per_session, "controlling_tty", return_value=tty),
            mock.patch.object(color_tab_per_session, "read_tab", side_effect=tab_wearing(profile, background)),
        ):
            on_session_start({"session_id": SESSION_ID})

        return json.loads((self.session_dir / "color.json").read_text())

    def test_saves_the_tab_look_on_the_first_start(self) -> None:
        """Ensure on_session_start saves the look the tab wears when the session first starts."""
        state = self.start(tty="/dev/ttys001", profile="Basic", background="0, 0, 0")
        self.assertEqual((state["saved_profile"], state["saved_background"]), ("Basic", "0, 0, 0"))

    def test_keeps_the_first_look_when_a_later_start_finds_the_session_color(self) -> None:
        """Ensure on_session_start keeps the first saved look when a compaction finds the tab already colored."""
        self.start(tty="/dev/ttys001", profile="Basic", background="0, 0, 0")
        state = self.start(tty="/dev/ttys001", profile="Ocean", background="1, 2, 3")
        self.assertEqual((state["saved_profile"], state["saved_background"]), ("Basic", "0, 0, 0"))

    def test_reads_the_tab_afresh_on_another_tty(self) -> None:
        """Ensure on_session_start reads the new tab's look when the session restarts on another tty."""
        self.start(tty="/dev/ttys001", profile="Basic", background="0, 0, 0")
        state = self.start(tty="/dev/ttys002", profile="Ocean", background="1, 2, 3")
        self.assertEqual((state["saved_profile"], state["saved_background"]), ("Ocean", "1, 2, 3"))


if __name__ == "__main__":
    unittest.main()
