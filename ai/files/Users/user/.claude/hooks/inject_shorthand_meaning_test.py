#!/usr/bin/env python3
"""
Tests for inject_shorthand_meaning: which prompts inject which shorthand entry.

Runs against the real `ai/contexts/shorthand.md` in this checkout, so a doc
edit that breaks the parser (a lost section heading, an entry with no tokens)
turns these red too.

    Usage:
        python ai/files/Users/user/.claude/hooks/inject_shorthand_meaning_test.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

from inject_shorthand_meaning import build_context, parse_doc

HOOKS_DIR = os.path.dirname(os.path.abspath(__file__))
HOOK_PATH = os.path.join(HOOKS_DIR, "inject_shorthand_meaning.py")
CONTEXTS_DIR = os.path.join(HOOKS_DIR, "..", "..", "..", "..", "..", "..", "ai", "contexts")
DOC_PATH = os.path.realpath(os.path.join(CONTEXTS_DIR, "shorthand.md"))


def write_transcript(directory: str, assistant_text: str) -> str:
    """
    Writes a one-turn transcript whose assistant message carries the given text.

    :param directory: Directory to write the transcript into.
    :param assistant_text: Text of the assistant's message (e.g. a menu).
    :return: Path to the transcript.
    """
    path = os.path.join(directory, "transcript.jsonl")
    records = [
        {"type": "user", "message": {"role": "user", "content": "go"}},
        {"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": assistant_text}]}},
    ]
    with open(path, "w", encoding="utf-8") as transcript:
        transcript.writelines(json.dumps(record) + "\n" for record in records)
    return path


class ParseDocTest(unittest.TestCase):
    """Test the `parse_doc` function."""

    def test_gives_every_entry_a_pattern(self) -> None:
        """Ensure parse_doc derives at least one pattern for every entry in the real doc."""
        with open(DOC_PATH, encoding="utf-8") as doc:
            whole, in_message = parse_doc(doc.read())
        for entry in whole + in_message:
            with self.subTest(entry=entry.text[:40]):
                self.assertTrue(entry.patterns)

    def test_raises_when_a_section_is_missing(self) -> None:
        """Ensure parse_doc raises ValueError when the in-message section is gone."""
        with self.assertRaises(ValueError):
            parse_doc("## Whole-message tokens\n\n- `y` means yes\n")


class BuildContextTest(unittest.TestCase):
    """Test the `build_context` function."""

    def assert_injects(self, prompt: str, expected_lead: str) -> None:
        """
        Asserts the prompt injects the entry that opens with the given lead.

        :param prompt: Prompt to feed the hook.
        :param expected_lead: Opening characters of the entry it should inject.
        """
        context = build_context(prompt, "", DOC_PATH)
        self.assertIn("\n- " + expected_lead, "\n" + context)

    def test_injects_the_entry_for_a_bare_token(self) -> None:
        """Ensure build_context injects the play entry when the whole prompt is play, in any case."""
        for prompt in ("play", "PLAY", "  play  "):
            with self.subTest(prompt=prompt):
                self.assert_injects(prompt, "`play` means")

    def test_injects_the_draft_entry_for_every_draft_form(self) -> None:
        """Ensure build_context injects the draft-pick entry for letter-first, number-first, paired and iterated picks."""
        for prompt in ("c2", "3c", "f4", "L2", "x1", "c2 c5", "c2 iter"):
            with self.subTest(prompt=prompt):
                self.assert_injects(prompt, "`c<N>` (e.g. `c2`) means")

    def test_injects_the_entry_for_a_pattern_with_an_argument(self) -> None:
        """Ensure build_context injects the matching pattern entry when the prompt carries an argument."""
        cases = {
            "2 iter": "`<N> iter` means",
            "a vs b": "`<x> vs <y>` or",
            "exp 1": "`exp <x>` means",
            "show me the menu": "`show me <x>` means",
            "w 2 4": "`w`, `weigh` mean",
        }
        for prompt, lead in cases.items():
            with self.subTest(prompt=prompt):
                self.assert_injects(prompt, lead)

    def test_returns_empty_for_a_question_about_a_token(self) -> None:
        """Ensure build_context returns "" when the prompt opens with a question word."""
        for prompt in ("what is play", "should I pick a vs b", "how does c2 work"):
            with self.subTest(prompt=prompt):
                self.assertEqual(build_context(prompt, "", DOC_PATH), "")

    def test_returns_empty_for_ordinary_prose(self) -> None:
        """Ensure build_context returns "" when no token appears, including near-miss words."""
        prompts = (
            "the cat sat",
            "status please",
            "look at the stack",
            "that was instant",
            "install stack",
            "the vista from here",
            "",
        )
        for prompt in prompts:
            with self.subTest(prompt=prompt):
                self.assertEqual(build_context(prompt, "", DOC_PATH), "")

    def test_injects_in_message_tokens(self) -> None:
        """Ensure build_context injects the in-message entry when its token is a word inside a longer prompt."""
        cases = {
            "copy that to cb": "`c`, `cb` mean",
            "ok sta please": "`sta` means",
            "do it nw": "`nw`, `nwt` mean",
            "where are we, sta?": "`sta` means",
            "give me the rundown, sta.": "`sta` means",
        }
        for prompt, lead in cases.items():
            with self.subTest(prompt=prompt):
                self.assert_injects(prompt, lead)

    def test_skips_a_token_quoted_in_code(self) -> None:
        """Ensure build_context returns "" when the only token sits in a code span."""
        self.assertEqual(build_context("rename the `cb` variable", "", DOC_PATH), "")

    def test_defers_to_an_offered_bracket_option(self) -> None:
        """Ensure build_context names the offered option instead of the table entry when the last message offered the letter."""
        with tempfile.TemporaryDirectory() as directory:
            transcript = write_transcript(directory, "Proceed?\n  ⚡ **`[n]ow`** (do it)\n  📋 **`[a]dd`** (bank it)")
            context = build_context("n", transcript, DOC_PATH)
        self.assertIn("`[n]`", context)
        self.assertNotIn('mean "no"', context)

    def test_uses_the_table_when_no_option_claims_the_letter(self) -> None:
        """Ensure build_context injects the table entry when the last message offered other letters only."""
        with tempfile.TemporaryDirectory() as directory:
            transcript = write_transcript(directory, "Proceed?\n  📋 **`[a]dd`** (bank it)")
            context = build_context("n", transcript, DOC_PATH)
        self.assertIn('mean "no"', context)


class HookContractTest(unittest.TestCase):
    """Test the hook's stdin/stdout contract."""

    def run_hook(self, payload: dict[str, str], contexts_dir: str) -> str:
        """
        Runs the hook as Claude Code would and returns its stdout.

        :param payload: UserPromptSubmit payload (e.g. {"prompt": "play"}).
        :param contexts_dir: Directory the hook reads `shorthand.md` from.
        :return: Hook stdout.
        """
        result = subprocess.run(
            [sys.executable, HOOK_PATH],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            check=True,
            env={**os.environ, "CLAUDE_CONTEXTS_DIR": contexts_dir},
        )
        return result.stdout

    def test_emits_additional_context_for_a_match(self) -> None:
        """Ensure the hook prints a UserPromptSubmit additionalContext payload when the prompt uses shorthand."""
        output = json.loads(self.run_hook({"prompt": "play"}, CONTEXTS_DIR))
        self.assertEqual(output["hookSpecificOutput"]["hookEventName"], "UserPromptSubmit")
        self.assertIn("`play` means", output["hookSpecificOutput"]["additionalContext"])

    def test_stays_silent_without_a_match(self) -> None:
        """Ensure the hook prints nothing when the prompt uses no shorthand."""
        self.assertEqual(self.run_hook({"prompt": "the cat sat"}, CONTEXTS_DIR), "")

    def test_points_at_the_doc_when_it_cannot_be_read(self) -> None:
        """Ensure the hook injects a failure pointer instead of staying silent when the doc is missing."""
        with tempfile.TemporaryDirectory() as directory:
            output = json.loads(self.run_hook({"prompt": "play"}, directory))
        self.assertIn("Shorthand hook failed", output["hookSpecificOutput"]["additionalContext"])


if __name__ == "__main__":
    unittest.main()
