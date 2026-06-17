#!/usr/bin/env python3
"""
Tests for log_permission_grants: what gets archived when a worktree is torn down.
"""

import json
import os
import tempfile
import unittest

from log_permission_grants import (
    append_entry,
    build_entry,
    hook_worktree,
    sanitize_permissions,
)

TIMESTAMP = "2026-06-09T14:03:21.512-07:00"


class SanitizePermissionsTest(unittest.TestCase):
    def test_masks_credentials_across_allow_deny_ask(self):
        settings = {
            "permissions": {
                "allow": ["Bash(git clone https://user:secretpassword@github.com/repo.git)"],
                "deny": ["Bash(curl https://user:pw@example.com)"],
                "ask": ["Read(/etc/passwd)"],
            }
        }
        sanitized = sanitize_permissions(settings)
        self.assertEqual(
            sanitized["permissions"]["allow"],
            ["Bash(git clone https://<REDACTED_CREDENTIALS>@github.com/repo.git)"],
        )
        self.assertEqual(
            sanitized["permissions"]["deny"],
            ["Bash(curl https://<REDACTED_CREDENTIALS>@example.com)"],
        )
        self.assertEqual(sanitized["permissions"]["ask"], ["Read(/etc/passwd)"])

    def test_leaves_settings_without_permissions_untouched(self):
        settings = {"model": "opus"}
        self.assertEqual(sanitize_permissions(settings), {"model": "opus"})


class HookWorktreeTest(unittest.TestCase):
    def test_returns_cwd_for_remove_action(self):
        payload = {"tool_name": "ExitWorktree", "tool_input": {"action": "remove"}, "cwd": "/wt"}
        self.assertEqual(hook_worktree(payload), "/wt")

    def test_skips_keep_action(self):
        payload = {"tool_name": "ExitWorktree", "tool_input": {"action": "keep"}, "cwd": "/wt"}
        self.assertIsNone(hook_worktree(payload))

    def test_skips_other_tools(self):
        payload = {"tool_name": "Edit", "tool_input": {"action": "remove"}, "cwd": "/wt"}
        self.assertIsNone(hook_worktree(payload))


class BuildEntryTest(unittest.TestCase):
    def test_returns_none_when_settings_absent(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertIsNone(build_entry(directory, "wtd", TIMESTAMP))

    def test_snapshots_settings_with_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            claude_dir = os.path.join(directory, ".claude")
            os.makedirs(claude_dir)
            settings = {"permissions": {"allow": ["Bash(ls)"]}}
            with open(os.path.join(claude_dir, "settings.local.json"), "w") as handle:
                json.dump(settings, handle)

            entry = build_entry(directory, "wtd", TIMESTAMP)
            self.assertEqual(entry["settings"], settings)
            self.assertEqual(entry["metadata"]["worktree"], directory)
            self.assertEqual(entry["metadata"]["reason"], "wtd")
            self.assertEqual(entry["metadata"]["timestamp"], TIMESTAMP)


class AppendEntryTest(unittest.TestCase):
    def test_appends_every_occurrence_as_jsonl(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "permission-grants.jsonl")
            entry = {"settings": {"permissions": {"allow": ["Bash(a)"]}}}

            append_entry(entry, path=path)
            append_entry(entry, path=path)

            with open(path, "r") as handle:
                lines = handle.readlines()
                self.assertEqual(len(lines), 2)
                self.assertEqual(json.loads(lines[0]), entry)
                self.assertEqual(json.loads(lines[1]), entry)


if __name__ == "__main__":
    unittest.main()
