#!/usr/bin/env python3
"""
Tests for open_status_on_commit_menu: how tall the status pane opens and the window record's cleanup.

Covers the row count the pane is fitted to and the record deleted at session
end; the Ghostty split and resize run through osascript against a live window,
so they stay out of the suite.
"""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import open_status_on_commit_menu
from open_status_on_commit_menu import PROMPT_ROWS
from open_status_on_commit_menu import forget_window
from open_status_on_commit_menu import rows_needed
from open_status_on_commit_menu import window_file


class RowsNeededTest(unittest.TestCase):
    """Test the `rows_needed` function."""

    def test_counts_one_row_per_short_line_plus_the_prompt(self) -> None:
        """Ensure rows_needed returns a row per line plus the prompt when every line fits the width."""
        lines = ["M\tai/foo.md", "A\tai/bar.md"]
        self.assertEqual(rows_needed(lines, 80), 2 + PROMPT_ROWS)

    def test_counts_wrapped_rows_for_a_long_line(self) -> None:
        """Ensure rows_needed counts each wrapped row when a line runs past the width."""
        lines = ["M\t" + "a" * 100]
        self.assertEqual(rows_needed(lines, 80), 2 + PROMPT_ROWS)

    def test_expands_the_status_tab_before_wrapping(self) -> None:
        """Ensure rows_needed measures the tab as its expanded width when it pushes a line past the width."""
        lines = ["M\t" + "a" * 75]
        self.assertEqual(rows_needed(lines, 80), 2 + PROMPT_ROWS)

    def test_counts_an_empty_line_as_one_row(self) -> None:
        """Ensure rows_needed returns one row for an empty line."""
        self.assertEqual(rows_needed([""], 80), 1 + PROMPT_ROWS)


class ForgetWindowTest(unittest.TestCase):
    """Test the `forget_window` function."""

    def setUp(self) -> None:
        state_dir = tempfile.TemporaryDirectory()
        self.addCleanup(state_dir.cleanup)
        patcher = mock.patch.object(open_status_on_commit_menu, "STATE_DIR", Path(state_dir.name))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.session_id = "12345678-90ab-cdef-1234-567890abcdef"

    def test_deletes_the_sessions_window_record(self) -> None:
        """Ensure forget_window deletes the record SessionStart wrote for the session."""
        window_file(self.session_id).write_text("1234")
        forget_window(self.session_id)
        self.assertFalse(window_file(self.session_id).exists())

    def test_leaves_other_sessions_records(self) -> None:
        """Ensure forget_window keeps another session's record, which that session still reads."""
        other = "abcdef12-3456-7890-abcd-ef1234567890"
        window_file(other).write_text("5678")
        forget_window(self.session_id)
        self.assertTrue(window_file(other).exists())

    def test_tolerates_a_missing_record(self) -> None:
        """Ensure forget_window returns quietly when the session never recorded a window."""
        forget_window(self.session_id)
        self.assertFalse(window_file(self.session_id).exists())


if __name__ == "__main__":
    unittest.main()
