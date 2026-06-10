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
    def test_reads_rule_from_suggestion_objects(self):
        payload = {
            "permission_suggestions": [
                {"rule": "Bash(npm *)", "description": "Allow npm commands"},
            ]
        }
        self.assertEqual(extract_rules(payload), ["Bash(npm *)"])

    def test_sanitizes_sensitive_data_in_rules(self):
        payload = {"permission_suggestions": ["Bash(git clone https://user:secretpassword@github.com/repo.git)"]}
        self.assertEqual(extract_rules(payload), ["Bash(git clone https://<REDACTED_CREDENTIALS>@github.com/repo.git)"])


class SynthesizeRuleTest(unittest.TestCase):
    def test_wraps_bash_command(self):
        payload = {"tool_name": "Bash", "tool_input": {"command": "git check-ignore foo"}}
        self.assertEqual(synthesize_rule(payload), "Bash(git check-ignore foo)")


class AppendEntryTest(unittest.TestCase):
    def test_appends_every_occurrence_as_jsonl(self):
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
