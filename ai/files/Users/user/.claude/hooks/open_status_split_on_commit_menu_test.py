#!/usr/bin/env python3
"""
Tests for open_status_split_on_commit_menu: how tall the status pane opens.

Covers the row count the pane is fitted to; the Ghostty split and resize run
through osascript against a live window, so they stay out of the suite.
"""

import unittest

from open_status_split_on_commit_menu import PROMPT_ROWS
from open_status_split_on_commit_menu import rows_needed


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


if __name__ == "__main__":
    unittest.main()
