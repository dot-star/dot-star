#!/usr/bin/env python3
"""
Tests for block_hidden_characters: which characters sink a Bash command.

Covers the detector directly and the stdin/stdout decision contract the hook
exposes to Claude Code.
"""

import json
import os
import subprocess
import sys
import unittest

from block_hidden_characters import build_deny, find_hidden_character

HOOK_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "block_hidden_characters.py")


class FindHiddenCharacterTest(unittest.TestCase):
    """Test the `find_hidden_character` function."""

    def test_returns_none_for_plain_ascii(self):
        """Ensure find_hidden_character returns None for a plain ASCII command."""
        self.assertIsNone(find_hidden_character("git log --oneline"))

    def test_returns_none_for_newlines_and_tabs(self):
        """Ensure find_hidden_character returns None for a multi-line, tab-indented command."""
        self.assertIsNone(find_hidden_character("if true; then\n\techo hi\nfi"))

    def test_returns_none_for_printable_non_ascii(self):
        """Ensure find_hidden_character returns None when the command carries emoji, accents, or a Nerd Font glyph."""
        for command in ('git commit -m "Café ✅"', "echo 🏁", "echo "):
            with self.subTest(command=command):
                self.assertIsNone(find_hidden_character(command))

    def test_returns_the_control_character(self):
        """Ensure find_hidden_character returns the control character hiding in a command."""
        for character in ("\x00", "\x0b", "\x0c", "\r", "\x1b"):
            with self.subTest(character=ascii(character)):
                self.assertEqual(find_hidden_character(f"git{character}log"), (3, character))

    def test_returns_none_for_an_exotic_space(self):
        """Ensure find_hidden_character returns None for a space character bash never splits on."""
        for character in ("\xa0", " ", "　"):
            with self.subTest(character=ascii(character)):
                self.assertIsNone(find_hidden_character(f"git{character}log"))

    def test_returns_the_zero_width_character(self):
        """Ensure find_hidden_character returns a zero-width character embedded in a command."""
        for character in ("​", "‍", "⁦"):
            with self.subTest(character=ascii(character)):
                self.assertEqual(find_hidden_character(f"git{character}log"), (3, character))

    def test_returns_the_separator(self):
        """Ensure find_hidden_character returns a line or paragraph separator, which renders as nothing."""
        for character in (" ", " "):
            with self.subTest(character=ascii(character)):
                self.assertEqual(find_hidden_character(f"git{character}log"), (3, character))

    def test_returns_the_first_hidden_character(self):
        """Ensure find_hidden_character returns the earliest offender when a command holds two."""
        self.assertEqual(find_hidden_character("a\x1bb\x00c"), (1, "\x1b"))


class BuildDenyTest(unittest.TestCase):
    """Test the `build_deny` function."""

    def test_names_the_offending_character(self):
        """Ensure build_deny reports the character's escape and Unicode name in the reason."""
        reason = build_deny(0, "‮")["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertIn("'\\u202e'", reason)
        self.assertIn("RIGHT-TO-LEFT OVERRIDE", reason)

    def test_reports_where_the_character_sits(self):
        """Ensure build_deny reports the character's index so a long command stays searchable."""
        reason = build_deny(42, "​")["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertIn("index 42", reason)

    def test_falls_back_for_an_unnamed_character(self):
        """Ensure build_deny still builds a reason when the character has no Unicode name."""
        reason = build_deny(0, "\x00")["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertIn("unnamed character", reason)


class MainDecisionTest(unittest.TestCase):
    """End-to-end stdin/stdout decision contract."""

    def test_denies_a_command_with_a_hidden_character(self):
        """Ensure main emits a deny decision for a command carrying a null byte."""
        result = run_hook({"tool_name": "Bash", "tool_input": {"command": "git\x00log"}})
        output = json.loads(result.stdout)
        self.assertEqual(output["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_stays_silent_for_a_clean_command(self):
        """Ensure main prints nothing for a command with no hidden character."""
        result = run_hook({"tool_name": "Bash", "tool_input": {"command": "git log"}})
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_non_bash_tool(self):
        """Ensure main prints nothing when the payload is not a Bash call."""
        result = run_hook({"tool_name": "Read", "tool_input": {"command": "git\x00log"}})
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_payload_that_is_not_an_object(self):
        """Ensure main prints nothing when the payload parses as JSON but is not an object."""
        result = run_hook(["Bash", {"command": "git\x00log"}])
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_non_object_tool_input(self):
        """Ensure main prints nothing when tool_input is not an object."""
        result = run_hook({"tool_name": "Bash", "tool_input": "git\x00log"})
        self.assertEqual(result.stdout.strip(), "")

    def test_ignores_a_non_string_command(self):
        """Ensure main prints nothing when the command is not a string."""
        for command in (None, 42, ["git\x00log"]):
            with self.subTest(command=command):
                result = run_hook({"tool_name": "Bash", "tool_input": {"command": command}})
                self.assertEqual(result.stdout.strip(), "")

    def test_ignores_unparseable_stdin(self):
        """Ensure main prints nothing when stdin is not valid JSON."""
        result = subprocess.run(
            [sys.executable, HOOK_PATH],
            input="not json",
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.stdout.strip(), "")


def run_hook(payload):
    """
    Runs the hook as a subprocess with a payload on stdin.

    :param payload: Hook event payload to serialize onto the hook's stdin
        (e.g. a well-formed event object, or a list the hook should ignore).
    :return: The completed process, carrying the hook's stdout.
    """
    return subprocess.run(
        [sys.executable, HOOK_PATH],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )


if __name__ == "__main__":
    unittest.main()
