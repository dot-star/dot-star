#!/usr/bin/env python3
"""
Tests for block_yubikey_otp: which prompts carry a YubiKey one-time password.

Covers the detector directly and the stdin/stdout decision contract the hook
exposes to Claude Code.
"""

import json
import os
import subprocess
import sys
import unittest

from block_yubikey_otp import contains_otp

HOOK_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "block_yubikey_otp.py")

# Build a placeholder OTP by counting through the modhex alphabet: a 6-byte
# public id plus the 16-byte token, the length a stock YubiKey types.
SAMPLE_OTP = "cccccbcdefgh" + "ijklnrtuvcbdefghijklnrtuvcbdefgh"


class ContainsOtpTest(unittest.TestCase):
    """Test the `contains_otp` function."""

    def test_returns_true_for_a_bare_otp(self) -> None:
        """Ensure contains_otp returns True when the prompt is only an OTP."""
        self.assertTrue(contains_otp(prompt=SAMPLE_OTP))

    def test_returns_true_for_an_otp_after_typed_text(self) -> None:
        """Ensure contains_otp returns True when an OTP trails a half-typed prompt."""
        self.assertTrue(contains_otp(prompt=f"can you check the {SAMPLE_OTP}"))

    def test_returns_true_for_an_uppercase_otp(self) -> None:
        """Ensure contains_otp returns True when Caps Lock typed the OTP in uppercase."""
        self.assertTrue(contains_otp(prompt=SAMPLE_OTP.upper()))

    def test_returns_true_for_the_length_bounds(self) -> None:
        """Ensure contains_otp returns True for an OTP with no public id and one with the longest."""
        for otp in (SAMPLE_OTP[12:], SAMPLE_OTP[12:] * 2):
            with self.subTest(otp=otp):
                self.assertTrue(contains_otp(prompt=otp))

    def test_returns_false_for_ordinary_prompts(self) -> None:
        """Ensure contains_otp returns False for prose, shorthand, a path, and a hex hash."""
        for prompt in (
            "can we hook block that yubikey accidental code?",
            "c",
            "/Users/user/Projects/dot-star/ai/files/Users/user/.claude/hooks",
            "1234567890abcdef1234567890abcdef12345678",
        ):
            with self.subTest(prompt=prompt):
                self.assertFalse(contains_otp(prompt=prompt))

    def test_returns_false_for_a_short_modhex_run(self) -> None:
        """Ensure contains_otp returns False for a modhex run shorter than the token."""
        self.assertFalse(contains_otp(prompt=SAMPLE_OTP[:31]))

    def test_returns_false_for_a_modhex_run_inside_a_longer_word(self) -> None:
        """Ensure contains_otp returns False when the modhex run abuts other letters or digits."""
        for prompt in (f"a{SAMPLE_OTP}", f"{SAMPLE_OTP}9"):
            with self.subTest(prompt=prompt):
                self.assertFalse(contains_otp(prompt=prompt))


class HookContractTest(unittest.TestCase):
    """Test the hook's stdin/stdout contract with Claude Code."""

    def run_hook(self, stdin: str) -> str:
        """
        Runs the hook as Claude Code would and returns what it printed.

        :param stdin: Raw text fed to the hook on stdin (e.g. a JSON payload).
        :return: The hook's stdout.
        """
        result = subprocess.run(
            [sys.executable, HOOK_PATH],
            input=stdin,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout

    def test_prints_a_block_decision_for_an_otp(self) -> None:
        """Ensure the hook prints a block decision when the prompt is an OTP."""
        output = json.loads(self.run_hook(stdin=json.dumps({"prompt": SAMPLE_OTP})))
        self.assertEqual(output["decision"], "block")

    def test_prints_nothing_for_an_ordinary_prompt(self) -> None:
        """Ensure the hook prints nothing when the prompt carries no OTP."""
        self.assertEqual(self.run_hook(stdin=json.dumps({"prompt": "hello"})), "")

    def test_prints_nothing_for_malformed_input(self) -> None:
        """Ensure the hook prints nothing when stdin is not a prompt payload."""
        for stdin in ("not json", "[]", '{"prompt": 7}'):
            with self.subTest(stdin=stdin):
                self.assertEqual(self.run_hook(stdin=stdin), "")


if __name__ == "__main__":
    unittest.main()
