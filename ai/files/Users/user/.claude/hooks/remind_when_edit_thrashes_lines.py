#!/usr/bin/env python3
"""
PostToolUse hook: remind Claude when an Edit rewrites whole lines to change a few words.

A diff shows every line an edit touches in full, so a one-clause change to a
long paragraph reads as a rewrite of the paragraph, and one word inserted into
hard-wrapped prose ripples through every line below it. Both show up as a gap
between line churn (characters on the changed lines) and word churn (characters
of the words that actually changed). A list where each item owns its line keeps
the two close.

The hook stays silent on a healthy edit and only speaks once the gap is wide
enough that restructuring first would visibly shrink the diff.

Usage:
    Wired in settings.json as a PostToolUse hook with a Write|Edit matcher.
"""

import json
import os
import sys
from difflib import SequenceMatcher

# Stay quiet below this much line churn; a short line has no better diff shape.
MIN_LINE_CHURN = 400

# Flag once the changed lines outweigh the changed words by this factor. A
# bullet rewritten outright scores near 1; a clause swapped inside a paragraph
# scores 10 or more.
MIN_CHURN_RATIO = 5

# Treat a line shorter than this as a fine diff unit already; splitting a
# mid-length bullet further buys the reviewer little.
MIN_LONG_LINE_LENGTH = 300

# Read the longest line shrinking below this share of its old width as a split
# into shorter lines, the restructure the reminder asks for.
MIN_KEPT_WIDTH = 0.75


def lines_around_edit(current: str, old_string: str, new_string: str) -> tuple[str, str] | None:
    """
    Returns the full lines an edit touched, as they read before and after it.

    Widens the replaced span to line boundaries, since the diff shows whole
    lines even when the edit swapped a fragment mid-line.

    :param current: File content after the edit.
    :param old_string: Text the edit replaced.
    :param new_string: Text the edit wrote in its place.
    :return: The touched lines before and after the edit, or None when the new
        text is empty or no longer in the file.
    """
    if not new_string:
        return None

    start = current.find(new_string)
    if start == -1:
        return None

    end = start + len(new_string)
    line_start = current.rfind("\n", 0, start) + 1
    line_end = current.find("\n", end)
    if line_end == -1:
        line_end = len(current)

    after = current[line_start:line_end]
    before = current[line_start:start] + old_string + current[end:line_end]
    return before, after


def changed_lines(before: str, after: str) -> tuple[list[str], list[str]]:
    """
    Returns the lines a line diff would mark as removed and added.

    :param before: Lines as they read before the edit.
    :param after: Lines as they read after the edit.
    :return: Removed lines and added lines, each in file order.
    """
    old_lines = before.splitlines()
    new_lines = after.splitlines()
    removed: list[str] = []
    added: list[str] = []
    for tag, i1, i2, j1, j2 in SequenceMatcher(a=old_lines, b=new_lines, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        removed.extend(old_lines[i1:i2])
        added.extend(new_lines[j1:j2])

    return removed, added


def measure_churn(removed: list[str], added: list[str]) -> tuple[int, int]:
    """
    Returns how much the line diff and the word diff each change.

    :param removed: Lines the diff marks as removed.
    :param added: Lines the diff marks as added.
    :return: Line churn (characters on removed plus added lines) and word churn
        (characters of removed plus added words within those lines).
    """
    line_churn = sum(len(line) for line in removed) + sum(len(line) for line in added)

    old_words = " ".join(removed).split()
    new_words = " ".join(added).split()
    word_churn = 0
    for tag, i1, i2, j1, j2 in SequenceMatcher(a=old_words, b=new_words, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        word_churn += sum(len(word) for word in old_words[i1:i2])
        word_churn += sum(len(word) for word in new_words[j1:j2])

    return line_churn, word_churn


def keeps_line_shape(removed: list[str], added: list[str]) -> bool:
    """
    Returns whether the edit left the lines shaped as they were.

    A split into bullets or an unwrap changes the line count or shortens the
    longest line; that is the restructure this hook recommends, never a thrash.

    :param removed: Lines the diff marks as removed.
    :param added: Lines the diff marks as added.
    :return: True when the line count moved by at most one and the longest line
        kept most of its width.
    """
    if not removed or not added or abs(len(removed) - len(added)) > 1:
        return False

    longest_removed = max(len(line) for line in removed)
    longest_added = max(len(line) for line in added)
    return longest_added >= MIN_KEPT_WIDTH * longest_removed


def moves_line_breaks(removed: list[str], added: list[str]) -> bool:
    """
    Returns whether most paired lines now end on a different word, as a reflow does.

    Tells rewrapped prose apart from several list items edited at once, where
    each item still ends where it did.

    :param removed: Lines the diff marks as removed.
    :param added: Lines the diff marks as added.
    :return: True when more than half the paired lines changed their last word.
    """
    pairs = list(zip(removed, added))
    if len(pairs) < 2:
        return False

    moved = 0
    for old_line, new_line in pairs:
        if old_line.split()[-1:] != new_line.split()[-1:]:
            moved += 1

    return moved * 2 > len(pairs)


def is_thrashing(removed: list[str], added: list[str]) -> bool:
    """
    Returns whether the line diff dwarfs the words that actually changed.

    :param removed: Lines the diff marks as removed.
    :param added: Lines the diff marks as added.
    :return: True when a long line or a rewrapped block churned for a few words
        and a restructure would shrink the diff.
    """
    line_churn, word_churn = measure_churn(removed, added)
    if (
        line_churn < MIN_LINE_CHURN
        or line_churn < MIN_CHURN_RATIO * max(word_churn, 1)
        or not keeps_line_shape(removed, added)
    ):
        return False

    longest = max(len(line) for line in removed + added)
    return longest >= MIN_LONG_LINE_LENGTH or moves_line_breaks(removed, added)


def build_reminder(file_path: str, line_churn: int, word_churn: int) -> dict[str, dict[str, str]]:
    """
    Builds the reminder naming the file and the churn gap.

    :param file_path: File the edit landed in.
    :param line_churn: Characters on the removed and added lines.
    :param word_churn: Characters of the removed and added words.
    :return: Hook output object ready to serialize to stdout.
    """
    context = (
        f"Diff churn: the edit to {file_path} rewrites {line_churn} characters of lines "
        f"to change {word_churn} characters of words. "
        "Split the long line into list items (or unwrap the reflowed block) as its own "
        "behavior-preserving commit first, so the change diffs as only the lines it means to touch."
    )
    return {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    }


def main() -> None:
    """Read the hook payload on stdin and print a reminder when an Edit thrashes lines."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return

    if not isinstance(payload, dict) or payload.get("tool_name") != "Edit":
        return

    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return

    file_path = tool_input.get("file_path")
    old_string = tool_input.get("old_string")
    new_string = tool_input.get("new_string")
    if not isinstance(file_path, str) or not isinstance(old_string, str) or not isinstance(new_string, str):
        return

    try:
        with open(os.path.expanduser(file_path), encoding="utf-8") as handle:
            current = handle.read()
    except (OSError, UnicodeDecodeError):
        return

    touched = lines_around_edit(current, old_string, new_string)
    if touched is None:
        return

    removed, added = changed_lines(*touched)
    if not is_thrashing(removed, added):
        return

    line_churn, word_churn = measure_churn(removed, added)
    json.dump(
        build_reminder(file_path, line_churn, word_churn),
        sys.stdout,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
