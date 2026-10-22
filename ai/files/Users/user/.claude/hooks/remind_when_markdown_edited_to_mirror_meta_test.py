#!/usr/bin/env python3
"""
Tests for remind_when_markdown_edited_to_mirror_meta: when a doc and its `.meta.md` drift.

Covers the line-shape comparison directly and the stdin/stdout reminder contract
the hook exposes to Claude Code.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

from remind_when_markdown_edited_to_mirror_meta import describe_drift
from remind_when_markdown_edited_to_mirror_meta import find_mismatches
from remind_when_markdown_edited_to_mirror_meta import line_shape
from remind_when_markdown_edited_to_mirror_meta import lines_match
from remind_when_markdown_edited_to_mirror_meta import pair_paths

HOOK_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "remind_when_markdown_edited_to_mirror_meta.py")

DOC = """# Rules

- Retry a failed upload once.
  - Cap the wait at ten seconds.
Plain paragraph line.
"""

META = """# Rules

- A flaky network drops one request in fifty.
  - A dead connection should fail fast.
Why the paragraph exists.
"""


class LineShapeTest(unittest.TestCase):
    """Test the `line_shape` function."""

    def test_keeps_indent_and_list_marker(self) -> None:
        """Ensure line_shape returns the indent and dash when the line is a nested bullet."""
        self.assertEqual(line_shape("  - Fix the bug"), "  -")

    def test_keeps_heading_level(self) -> None:
        """Ensure line_shape returns the hashes when the line is a heading."""
        self.assertEqual(line_shape("## Workflow"), "##")

    def test_keeps_numbered_marker(self) -> None:
        """Ensure line_shape returns the number when the line is an ordered item."""
        self.assertEqual(line_shape("    3. Count the options"), "    3.")

    def test_keeps_quote_depth(self) -> None:
        """Ensure line_shape returns both quote markers when the line is nested in quotes."""
        self.assertEqual(line_shape("  > > Uppercase the letter"), "  > >")

    def test_keeps_fence(self) -> None:
        """Ensure line_shape returns the backticks when the line opens a fence with a language."""
        self.assertEqual(line_shape("```python"), "```")

    def test_reads_bold_as_plain(self) -> None:
        """Ensure line_shape returns only the indent when the line opens with bold text."""
        self.assertEqual(line_shape("  **Slot order:** first"), "")

    def test_reads_rule_as_plain(self) -> None:
        """Ensure line_shape returns an empty shape when the line is a horizontal rule."""
        self.assertEqual(line_shape("---"), "")


class LinesMatchTest(unittest.TestCase):
    """Test the `lines_match` function."""

    def test_accepts_marker_only_meta_line(self) -> None:
        """Ensure lines_match accepts a meta line carrying only the doc line's marker."""
        self.assertTrue(lines_match("  - Fix the bug", "  -"))

    def test_accepts_blank_meta_for_plain_line(self) -> None:
        """Ensure lines_match accepts an empty meta line when the doc line is plain prose."""
        self.assertTrue(lines_match("Plain paragraph.", ""))

    def test_rejects_blank_meta_for_bullet(self) -> None:
        """Ensure lines_match rejects an empty meta line when the doc line is a bullet."""
        self.assertFalse(lines_match("- Fix the bug", ""))

    def test_rejects_prose_on_blank_doc_line(self) -> None:
        """Ensure lines_match rejects reasoning written where the doc line is blank."""
        self.assertFalse(lines_match("", "Some reasoning."))

    def test_rejects_shifted_indent(self) -> None:
        """Ensure lines_match rejects a meta bullet indented differently from its doc bullet."""
        self.assertFalse(lines_match("  - Fix the bug", "- Because"))


class FindMismatchesTest(unittest.TestCase):
    """Test the `find_mismatches` function."""

    def test_returns_empty_for_aligned_pair(self) -> None:
        """Ensure find_mismatches returns nothing when every line keeps its shape."""
        self.assertEqual(find_mismatches(DOC, META), [])

    def test_returns_drifted_line_numbers(self) -> None:
        """Ensure find_mismatches returns the 1-based number of each drifted line."""
        drifted = META.replace("  - A dead", "- A dead")
        self.assertEqual(find_mismatches(DOC, drifted), [4])


class PairPathsTest(unittest.TestCase):
    """Test the `pair_paths` function."""

    def test_pairs_doc_with_meta(self) -> None:
        """Ensure pair_paths returns the meta beside the doc when the doc was edited."""
        self.assertEqual(
            pair_paths("/home/.claude/CLAUDE.md"), ("/home/.claude/CLAUDE.md", "/home/.claude/CLAUDE.meta.md")
        )

    def test_pairs_meta_with_doc(self) -> None:
        """Ensure pair_paths returns the same pair when the meta was edited."""
        self.assertEqual(
            pair_paths("/home/.claude/CLAUDE.meta.md"), ("/home/.claude/CLAUDE.md", "/home/.claude/CLAUDE.meta.md")
        )

    def test_skips_non_markdown(self) -> None:
        """Ensure pair_paths returns None when the file is not markdown."""
        self.assertIsNone(pair_paths("/repo/install.sh"))

    def test_pairs_instruction_docs(self) -> None:
        """Ensure pair_paths returns a pair for each instruction doc location."""
        for path in (
            "/home/.claude/CLAUDE.md",
            "/home/.claude/CLAUDE_foo.md",
            "/home/.claude/skills/foo/SKILL.md",
            "/home/.claude/styles/shell-style.md",
            "/repo/ai/contexts/code-style.md",
        ):
            with self.subTest(path=path):
                self.assertIsNotNone(pair_paths(path))

    def test_skips_other_markdown(self) -> None:
        """Ensure pair_paths returns None for markdown outside the instruction docs."""
        for path in (
            "/home/.claude/agents/foo.md",
            "/home/.claude/commands/commit.md",
            "/home/.claude/plans/some-plan.md",
            "/home/.claude/projects/repo/memory/MEMORY.md",
            "/home/.claude/skills/foo/reference.md",
            "/private/tmp/claude-501/repo/12345678/scratchpad/notes.md",
            "/repo/CHANGELOG.md",
            "/repo/CLAUDE.md",
            "/repo/README.md",
            "/repo/todo.md",
        ):
            with self.subTest(path=path):
                self.assertIsNone(pair_paths(path))


class DescribeDriftTest(unittest.TestCase):
    """Test the `describe_drift` function."""

    def test_returns_none_for_aligned_pair(self) -> None:
        """Ensure describe_drift returns None when the pair lines up."""
        self.assertIsNone(describe_drift("a.md", "a.meta.md", DOC, META))

    def test_names_missing_meta(self) -> None:
        """Ensure describe_drift names the meta path when the companion is missing."""
        reminder = describe_drift("a.md", "a.meta.md", DOC, None)
        assert reminder is not None
        self.assertIn("missing: create a.meta.md", reminder)

    def test_asks_for_skeleton_commit_when_meta_missing(self) -> None:
        """Ensure describe_drift asks for a prose-free skeleton commit ahead of the change."""
        reminder = describe_drift("a.md", "a.meta.md", DOC, None)
        assert reminder is not None
        self.assertIn("prose-free skeleton", reminder)

    def test_names_line_count_gap(self) -> None:
        """Ensure describe_drift names both counts when the meta is short a line."""
        reminder = describe_drift("a.md", "a.meta.md", DOC, META + "Extra.\n")
        assert reminder is not None
        self.assertIn("a.md has 5 lines but a.meta.md has 6", reminder)

    def test_caps_listed_lines(self) -> None:
        """Ensure describe_drift lists the first mismatches and counts the rest."""
        doc = "- a\n" * 8
        meta = "  - a\n" * 8
        reminder = describe_drift("a.md", "a.meta.md", doc, meta)
        assert reminder is not None
        self.assertIn("at line 1, 2, 3, 4, 5 and 3 more", reminder)


class HookContractTest(unittest.TestCase):
    """End-to-end stdin/stdout contract of the hook script."""

    def run_hook(self, tool_name: str, file_path: str) -> str:
        """
        Returns the hook's stdout for one tool payload.

        :param tool_name: Tool the payload names (e.g. "Edit").
        :param file_path: File the tool wrote.
        :return: Whatever the hook printed.
        """
        payload = {"tool_input": {"file_path": file_path}, "tool_name": tool_name}
        result = subprocess.run(
            [sys.executable, HOOK_PATH],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout

    def write(self, path: str, text: str) -> None:
        """
        Writes a fixture file.

        :param path: File to write.
        :param text: Content to write.
        """
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)

    def make_contexts_dir(self, root: str) -> str:
        """
        Creates an `ai/contexts/` directory, where every doc is an instruction doc.

        :param root: Directory to create it under.
        :return: Path of the new directory.
        """
        directory = os.path.join(root, "ai", "contexts")
        os.makedirs(directory)
        return directory

    def test_reminds_when_meta_missing(self) -> None:
        """Ensure the hook prints a PostToolUse reminder when the doc has no companion."""
        with tempfile.TemporaryDirectory() as root:
            doc_path = os.path.join(self.make_contexts_dir(root), "foo.md")
            self.write(doc_path, DOC)
            output = json.loads(self.run_hook("Write", doc_path))
        self.assertEqual(output["hookSpecificOutput"]["hookEventName"], "PostToolUse")
        self.assertIn("Meta companion missing", output["hookSpecificOutput"]["additionalContext"])

    def test_silent_when_pair_aligned(self) -> None:
        """Ensure the hook prints nothing when the meta mirrors the doc."""
        with tempfile.TemporaryDirectory() as root:
            directory = self.make_contexts_dir(root)
            doc_path = os.path.join(directory, "foo.md")
            self.write(doc_path, DOC)
            self.write(os.path.join(directory, "foo.meta.md"), META)
            self.assertEqual(self.run_hook("Edit", doc_path), "")

    def test_silent_for_readme_without_meta(self) -> None:
        """Ensure the hook prints nothing when a README outside the instruction docs has no companion."""
        with tempfile.TemporaryDirectory() as root:
            doc_path = os.path.join(root, "README.md")
            self.write(doc_path, DOC)
            self.assertEqual(self.run_hook("Write", doc_path), "")

    def test_silent_for_other_tools(self) -> None:
        """Ensure the hook prints nothing when the payload names a tool other than Edit or Write."""
        self.assertEqual(self.run_hook("Read", "/repo/README.md"), "")


if __name__ == "__main__":
    unittest.main()
