#!/usr/bin/env python3
"""
PreToolUse hook: deny Bash commands carrying invisible characters.

Reads the hook event JSON on stdin and prints a deny decision when the command
holds a character the reader cannot see: a control character, a format
character, or a line/paragraph separator. Some of those actively mislead (an
escape sequence repaints the screen, a carriage return overwrites the line
already drawn, a right-to-left override reorders the text around it) and the
rest merely occupy no width, which is enough on its own. The test is whether
the character survives the trip to the reader's eye, not whether the terminal
acts on it.

The target is the human approving the command, not the rule matcher. A hidden
character does not win a silent allow from the matcher (it lands on `unmatched`,
which still prompts), and bash splits words on space, tab, and newline only, so
a zero-width space sits mid-word rather than starting a second command.

Visible lookalikes stay allowed and are the wider gap: a Cyrillic `а`, a
fullwidth `／`, or a stacked combining mark each deceive a reader better than
anything blocked here. Closing that gap takes a confusables table rather than a
category filter.

Newlines and tabs pass, since multi-line commands and heredocs are ordinary
usage. Emoji, accents, and Nerd Font glyphs pass. A multi-part emoji joined by
U+200D (e.g. a profession or family sequence) does not, since the same joiner is
what splices an invisible seam into a command.

Usage:
    Wired in settings.json as a PreToolUse hook with a Bash matcher.
"""

import json
import sys
import unicodedata

# Allow the two whitespace characters that legitimately structure a command.
ALLOWED_WHITESPACE = frozenset(
    [
        "\n",
        "\t",
    ]
)

# Deny the Unicode general categories that reach the reader as nothing at all.
FORBIDDEN_CATEGORIES = frozenset(
    [
        "Cc",  # Reject control characters (an escape sequence, a carriage return).
        "Cf",  # Reject format characters (a bidi override, a zero-width joiner).
        "Zl",  # Reject the line separator, which hides a seam the way U+200B does.
        "Zp",  # Reject the paragraph separator, for the same reason as U+2028.
    ]
)


def find_hidden_character(command: str) -> tuple[int, str] | None:
    """
    Returns the position and value of the first invisible character in a command.

    :param command: Bash command as submitted by the tool call.
    :return: The offending character and its index, or None when every character
        is visible.
    """
    for index, character in enumerate(command):
        if character in ALLOWED_WHITESPACE:
            continue
        elif unicodedata.category(character) in FORBIDDEN_CATEGORIES:
            return index, character

    return None


def build_deny(index: int, character: str) -> dict:
    """
    Builds the deny decision naming the offending character and where it sits.

    The index lets the caller rewrite the command without hunting for a
    character it cannot see; the reason alone leaves a long heredoc unsearchable.

    :param index: Zero-based position of the character within the command.
    :param character: Hidden character found in the command.
    :return: Hook output object ready to serialize to stdout.
    """
    name = unicodedata.name(character, "unnamed character")
    reason = f"Command contains a hidden character at index {index}: {ascii(character)} ({name})."
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def main() -> None:
    """Read the hook payload on stdin and print a deny decision for a hidden character."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # Fall through to the normal permission flow when stdin is not valid JSON.
        return

    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return

    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return

    command = tool_input.get("command")
    if not isinstance(command, str):
        return

    found = find_hidden_character(command)
    if found is None:
        # Print nothing so the command falls through to the normal permission flow.
        return

    index, character = found

    # Print the deny decision. Exit code 2 is only a non-blocking error for this
    # event, so the decision object is what actually stops the call.
    json.dump(
        build_deny(index, character),
        sys.stdout,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
