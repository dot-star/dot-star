#!/usr/bin/env python3
"""
Tests for remind_when_edit_thrashes_lines: which edits churn more lines than words.

Covers the churn measurement directly and the stdin/stdout reminder contract the
hook exposes to Claude Code.
"""

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from remind_when_edit_thrashes_lines import (
    build_reminder,
    changed_lines,
    is_thrashing,
    lines_around_edit,
    measure_churn,
)

HOOK_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "remind_when_edit_thrashes_lines.py")

# Build a paragraph long enough to clear the churn floor on its own.
PARAGRAPH = " ".join(f"clause{index} carries some rule text" for index in range(20))

# Hold one long rule on a single line, the shape the hook exists to flag.
RULE = (
    "- Retry a failed upload before surfacing the error: a flaky network drops one request in fifty, "
    "and the retry hides that from the reader without masking a real outage, since a second failure "
    "still reports. Cap the wait at ten seconds so a dead connection fails fast instead of hanging the "
    "prompt, and log each retry to the debug file so a pattern of drops stays visible to whoever tunes "
    "the timeout later."
)

# Hold the same rule split into sub-bullets, one per sentence.
SPLIT_RULE = """- Retry a failed upload before surfacing the error:
  - a flaky network drops one request in fifty, and the retry hides that from the reader without masking a real outage, since a second failure still reports.
  - Cap the wait at ten seconds so a dead connection fails fast instead of hanging the prompt, and log each retry to the debug file so a pattern of drops stays visible to whoever tunes the timeout later."""


class LinesAroundEditTest(unittest.TestCase):
    """Test the `lines_around_edit` function."""

    def test_widens_a_fragment_to_its_whole_line(self) -> None:
        """Ensure lines_around_edit returns the full line when the edit swapped a word mid-line."""
        current = "first\nalpha NEW gamma\nlast\n"
        self.assertEqual(lines_around_edit(current, "OLD", "NEW"), ("alpha OLD gamma", "alpha NEW gamma"))

    def test_keeps_multi_line_edits_whole(self) -> None:
        """Ensure lines_around_edit returns every line a multi-line edit spans."""
        current = "head\none\ntwo\ntail"
        self.assertEqual(lines_around_edit(current, "uno\ndos", "one\ntwo"), ("uno\ndos", "one\ntwo"))

    def test_returns_none_for_an_empty_replacement(self) -> None:
        """Ensure lines_around_edit returns None when the edit deleted its text outright."""
        self.assertIsNone(lines_around_edit("kept\n", "gone", ""))

    def test_returns_none_when_the_new_text_is_missing(self) -> None:
        """Ensure lines_around_edit returns None when the file no longer holds the new text."""
        self.assertIsNone(lines_around_edit("unrelated\n", "old", "new"))


class ChangedLinesTest(unittest.TestCase):
    """Test the `changed_lines` function."""

    def test_skips_unchanged_lines(self) -> None:
        """Ensure changed_lines returns only the lines the diff marks as removed and added."""
        self.assertEqual(changed_lines("- keep\n- old", "- keep\n- new"), (["- old"], ["- new"]))


class MeasureChurnTest(unittest.TestCase):
    """Test the `measure_churn` function."""

    def test_counts_the_whole_line_for_a_one_word_swap(self) -> None:
        """Ensure measure_churn counts both copies of the line but only the swapped words."""
        line_churn, word_churn = measure_churn(["alpha beta gamma"], ["alpha delta gamma"])
        self.assertEqual(line_churn, len("alpha beta gamma") + len("alpha delta gamma"))
        self.assertEqual(word_churn, len("beta") + len("delta"))

    def test_scores_a_reflow_as_no_word_churn(self) -> None:
        """Ensure measure_churn reports zero word churn when wrapped text only moves between lines."""
        self.assertEqual(measure_churn(textwrap.wrap(PARAGRAPH, 60), textwrap.wrap(PARAGRAPH, 70))[1], 0)


class IsThrashingTest(unittest.TestCase):
    """Test the `is_thrashing` function."""

    def test_flags_a_clause_swapped_inside_a_long_line(self) -> None:
        """Ensure is_thrashing returns True when one clause changes inside a long rule line."""
        after = RULE.replace("at ten seconds", "at ten seconds (thirty on a metered link)")
        self.assertTrue(thrashes(RULE, after))

    def test_flags_a_reflowed_block(self) -> None:
        """Ensure is_thrashing returns True when one inserted word rewraps hard-wrapped prose."""
        before = "\n".join(textwrap.wrap(PARAGRAPH, 60))
        after = "\n".join(textwrap.wrap("inserted " + PARAGRAPH, 60))
        self.assertTrue(thrashes(before, after))

    def test_passes_a_split_into_bullets(self) -> None:
        """Ensure is_thrashing returns False when a long line is split into sub-bullets."""
        self.assertFalse(thrashes(RULE, SPLIT_RULE))

    def test_passes_an_unwrap(self) -> None:
        """Ensure is_thrashing returns False when hard-wrapped prose is joined onto one line."""
        self.assertFalse(thrashes("\n".join(textwrap.wrap(PARAGRAPH, 60)), PARAGRAPH))

    def test_passes_a_clause_swapped_inside_a_mid_length_bullet(self) -> None:
        """Ensure is_thrashing returns False when the changed bullet is already a fine diff unit."""
        after = SPLIT_RULE.replace("at ten seconds", "at ten seconds (thirty on a metered link)")
        self.assertFalse(thrashes(SPLIT_RULE, after))

    def test_passes_several_bullets_edited_at_once(self) -> None:
        """Ensure is_thrashing returns False when adjacent mid-length bullets each change a word."""
        before = "\n".join(f"- bullet{index} {PARAGRAPH[:200]} end{index}" for index in range(3))
        after = before.replace("clause1 carries", "clause1 holds")
        self.assertFalse(thrashes(before, after))

    def test_passes_a_rewritten_line(self) -> None:
        """Ensure is_thrashing returns False when a long line is rewritten outright."""
        after = " ".join(f"entry{index} says something else" for index in range(20))
        self.assertFalse(thrashes(PARAGRAPH, after))

    def test_passes_an_added_bullet(self) -> None:
        """Ensure is_thrashing returns False when the edit only adds a new line."""
        self.assertFalse(thrashes("- first", "- first\n- " + PARAGRAPH))

    def test_passes_a_short_line_tweak(self) -> None:
        """Ensure is_thrashing returns False when the changed line is too short to restructure."""
        self.assertFalse(thrashes("retry three times", "retry four times"))


class BuildReminderTest(unittest.TestCase):
    """Test the `build_reminder` function."""

    def test_names_the_file_and_both_churn_figures(self) -> None:
        """Ensure build_reminder reports the file and both churn counts in its context."""
        context = build_reminder("/tmp/notes.md", 900, 40)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("/tmp/notes.md", context)
        self.assertIn("900", context)
        self.assertIn("40", context)


class MainReminderTest(unittest.TestCase):
    """End-to-end stdin/stdout reminder contract."""

    def test_reminds_after_a_thrashing_edit(self) -> None:
        """Ensure main emits a reminder after a clause swap inside a long line."""
        new_string = "clause7 now carries"
        with edited_file(PARAGRAPH.replace("clause7 carries", new_string) + "\n") as path:
            result = run_hook(edit_payload(path, "clause7 carries", new_string))
        output = json.loads(result.stdout)
        self.assertEqual(output["hookSpecificOutput"]["hookEventName"], "PostToolUse")

    def test_stays_silent_after_a_clean_edit(self) -> None:
        """Ensure main prints nothing after an edit that adds its own line."""
        with edited_file("- first\n- second\n") as path:
            result = run_hook(edit_payload(path, "- first", "- first\n- second"))
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_write(self) -> None:
        """Ensure main prints nothing for a Write, which carries no old text to compare."""
        result = run_hook({"tool_name": "Write", "tool_input": {"file_path": "/nonexistent", "content": PARAGRAPH}})
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_missing_file(self) -> None:
        """Ensure main prints nothing when the edited file can no longer be read."""
        result = run_hook(edit_payload("/nonexistent/notes.md", "old", "new"))
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_non_string_field(self) -> None:
        """Ensure main prints nothing when an edit field is not a string."""
        result = run_hook(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x", "old_string": 1, "new_string": 2}}
        )
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_unparseable_stdin(self) -> None:
        """Ensure main prints nothing when stdin is not valid JSON."""
        result = subprocess.run(
            [sys.executable, HOOK_PATH],
            input="not json",
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.stdout.strip(), "")


def thrashes(before: str, after: str) -> bool:
    """
    Returns whether the hook would flag an edit from one text to another.

    :param before: Lines as they read before the edit.
    :param after: Lines as they read after the edit.
    :return: The `is_thrashing` verdict on the lines the diff marks as changed.
    """
    return is_thrashing(*changed_lines(before, after))


@contextmanager
def edited_file(content: str) -> Iterator[str]:
    """
    Yields the path of a temporary file holding the post-edit content.

    :param content: File content as it reads after the edit.
    :return: Path of the file, removed once the block exits.
    """
    handle, path = tempfile.mkstemp(suffix=".md")
    with os.fdopen(handle, "w", encoding="utf-8") as file:
        file.write(content)
    try:
        yield path
    finally:
        os.unlink(path)


def edit_payload(path: str, old_string: str, new_string: str) -> dict[str, Any]:
    """
    Builds the PostToolUse payload for an Edit call.

    :param path: File the edit landed in.
    :param old_string: Text the edit replaced.
    :param new_string: Text the edit wrote in its place.
    :return: Hook event payload ready to serialize onto stdin.
    """
    return {
        "tool_name": "Edit",
        "tool_input": {
            "file_path": path,
            "old_string": old_string,
            "new_string": new_string,
        },
    }


def run_hook(payload: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    """
    Runs the hook as a subprocess with a payload on stdin.

    :param payload: Hook event payload to serialize onto the hook's stdin.
    :return: The completed process, carrying the hook's stdout.
    """
    return subprocess.run(
        [sys.executable, HOOK_PATH],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        check=False,
    )


if __name__ == "__main__":
    unittest.main()
