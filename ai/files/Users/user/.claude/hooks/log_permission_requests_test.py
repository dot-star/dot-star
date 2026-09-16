#!/usr/bin/env python3
"""
Tests for log_permission_requests: what gets appended to the review log.
"""

import json
import os
import tempfile
import unittest

from log_permission_requests import (
    append_entry,
    extract_rules,
    synthesize_rule,
)

TIMESTAMP = "2026-06-09T14:03:21.512-07:00"


class ExtractRulesTest(unittest.TestCase):
    def test_reads_rule_from_suggestion_objects(self) -> None:
        payload = {
            "permission_suggestions": [
                {"rule": "Bash(npm *)", "description": "Allow npm commands"},
            ]
        }
        self.assertEqual(extract_rules(payload), ["Bash(npm *)"])

    def test_sanitizes_sensitive_data_in_rules(self) -> None:
        payload = {"permission_suggestions": ["Bash(git clone https://user:secretpassword@github.com/repo.git)"]}
        self.assertEqual(extract_rules(payload), ["Bash(git clone https://<REDACTED_CREDENTIALS>@github.com/repo.git)"])


class SynthesizeRuleTest(unittest.TestCase):
    def test_wraps_bash_command(self) -> None:
        payload = {"tool_name": "Bash", "tool_input": {"command": "git check-ignore foo"}}
        self.assertEqual(synthesize_rule(payload), "Bash(git check-ignore foo)")

    def test_wraps_file_tool_path_in_rule_syntax(self) -> None:
        """Ensure synthesize_rule spells an absolute file_path with the double-slash rule prefix."""
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "/Users/user/Projects/foo/bar.py"}}
        self.assertEqual(synthesize_rule(payload), "Edit(//Users/user/Projects/foo/bar.py)")

    def test_keeps_relative_file_path_bare(self) -> None:
        """Ensure synthesize_rule leaves a relative file_path unprefixed."""
        payload = {"tool_name": "Write", "tool_input": {"file_path": "notes/todo.md"}}
        self.assertEqual(synthesize_rule(payload), "Write(notes/todo.md)")

    def test_falls_back_to_tool_name_without_a_path(self) -> None:
        """Ensure synthesize_rule returns the bare tool name when tool_input carries no file_path."""
        payload = {"tool_name": "AskUserQuestion", "tool_input": {"questions": []}}
        self.assertEqual(synthesize_rule(payload), "AskUserQuestion")


class AppendEntryTest(unittest.TestCase):
    def test_appends_every_occurrence_as_jsonl(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "permission-requests.jsonl")
            entry = {"permissions": {"allow": ["Bash(a)"]}}

            append_entry(entry, path=path)
            append_entry(entry, path=path)

            with open(path, "r") as handle:
                lines = handle.readlines()
                self.assertEqual(len(lines), 2)
                self.assertEqual(json.loads(lines[0]), entry)
                self.assertEqual(json.loads(lines[1]), entry)


if __name__ == "__main__":
    unittest.main()
