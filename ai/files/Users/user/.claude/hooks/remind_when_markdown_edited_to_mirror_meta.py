#!/usr/bin/env python3
"""
PostToolUse hook: remind Claude when a markdown file and its `.meta.md` companion fall out of step.

Every instruction doc `<name>.md` carries a `<name>.meta.md` beside it: the `.md`
holds the trimmed rules, the meta holds the reasoning behind each one on the
same line number. The two stay line-for-line aligned, so line N of the meta
always explains line N of the doc. Each meta line keeps its doc line's format
(indentation, list marker, heading level, quote depth, fence) even when it
carries no prose.

The hook stays silent while the pair lines up and speaks only when the
companion is missing, a line's shape drifted or a meta line credits its
reasoning to someone or stamps it with a date.

Usage:
    Wired in settings.json as a PostToolUse hook with a Write|Edit matcher.
"""

import fnmatch
import json
import os
import re
import sys

META_SUFFIX = ".meta.md"

# Match the structural prefix of a markdown line: any quote depth, then one
# heading, list marker or fence. A marker counts only when whitespace or the
# line end follows it, so `**bold**` and `---` read as plain text.
MARKER = re.compile(r"(?:>[ \t]?)*(?:(?:#{1,6}|[-*+]|\d+[.)])(?=\s|$)|`{3,}|~{3,})?")

# Name the most mismatched lines a reminder lists before it stops counting.
MAX_REPORTED_LINES = 5

# Flag reasoning that says who gave it or when instead of why. Every line is the
# user's rule, so the credit adds nothing and git history already holds the date.
CREDIT_PATTERNS = (
    # Catch a passive credit (`Stated by the user`, `Scope narrowed by the user`).
    re.compile(r"\b(?:\w+ed|chosen|said) by the user\b", re.IGNORECASE),
    # Catch an active credit (`the user ruled`, `the user chose`).
    re.compile(r"\bthe user (?:\w+ed|chose|said)\b", re.IGNORECASE),
    # Catch a prose date (`Thu, Oct 22`).
    re.compile(r"\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{1,2}\b"),
    # Catch an ISO date (`2026-10-22`).
    re.compile(r"\b\d{4}-\d{2}-\d{2}\b"),
)

# Match only the instruction docs the rule covers, so another repo's markdown and
# a directory that loads every `.md` it holds (`commands/`, `agents/`) never get a companion.
INSTRUCTION_DOC_PATTERNS = (
    "*/.claude/CLAUDE.md",
    "*/.claude/CLAUDE_*.md",
    "*/.claude/skills/*/SKILL.md",
    "*/.claude/styles/*.md",
    "*/ai/contexts/*.md",
)


def is_instruction_doc(path: str) -> bool:
    """
    Returns whether a markdown file is one of the instruction docs the rule covers.

    :param path: Absolute path of the markdown file (e.g. `/repo/ai/contexts/code-style.md`).
    :return: True for the user-global `CLAUDE.md`, `CLAUDE_*.md` supplementals,
        skills, style guides and context docs.
    """
    for pattern in INSTRUCTION_DOC_PATTERNS:
        if fnmatch.fnmatchcase(path, pattern):
            return True

    return False


def pair_paths(path: str) -> tuple[str, str] | None:
    """
    Returns the doc and meta paths for an edited markdown file, whichever side was edited.

    :param path: Absolute path the edit landed in (e.g. `/repo/CLAUDE.md`).
    :return: The doc path and its meta path, or None when the file isn't
        an instruction doc.
    """
    if path.endswith(META_SUFFIX):
        doc_path = path[: -len(META_SUFFIX)] + ".md"
    elif path.endswith(".md"):
        doc_path = path
    else:
        return None

    if not is_instruction_doc(doc_path):
        return None

    return doc_path, doc_path[: -len(".md")] + META_SUFFIX


def line_shape(line: str) -> str:
    """
    Returns a line's format with its prose stripped.

    :param line: One markdown line without its newline (e.g. `  - Fix the bug`).
    :return: The indentation plus any quote, heading, list or fence marker
        (e.g. `  -`), or an empty string for a blank line.
    """
    if not line.strip():
        return ""

    body = line.lstrip()
    indent = line[: len(line) - len(body)]
    match = MARKER.match(body)
    if match is None:
        return indent.rstrip()

    return (indent + match.group(0)).rstrip()


def lines_match(doc_line: str, meta_line: str) -> bool:
    """
    Returns whether a meta line keeps the format of the doc line it explains.

    :param doc_line: Line from the `.md` file.
    :param meta_line: Line at the same number in the `.meta.md` file.
    :return: True when both are blank, when a plain doc line faces a blank
        meta line (no reasoning yet), or when both share one shape.
    """
    if not doc_line.strip():
        return not meta_line.strip()
    elif not meta_line.strip():
        return not line_shape(doc_line).strip()

    return line_shape(doc_line) == line_shape(meta_line)


def find_mismatches(doc_text: str, meta_text: str) -> list[int]:
    """
    Returns the 1-based numbers of the lines whose shapes disagree.

    :param doc_text: Full content of the `.md` file.
    :param meta_text: Full content of the `.meta.md` file.
    :return: Line numbers present in both files whose meta line breaks the
        doc line's format, in file order.
    """
    mismatches: list[int] = []
    for number, (doc_line, meta_line) in enumerate(
        zip(doc_text.splitlines(), meta_text.splitlines(), strict=False), start=1
    ):
        if not lines_match(doc_line, meta_line):
            mismatches.append(number)

    return mismatches


def describe_drift(doc_path: str, meta_path: str, doc_text: str, meta_text: str | None) -> str | None:
    """
    Returns the reminder text for a pair out of step, or None when it lines up.

    :param doc_path: Path of the `.md` file.
    :param meta_path: Path of the `.meta.md` file.
    :param doc_text: Content of the `.md` file.
    :param meta_text: Content of the `.meta.md` file, or None when it is missing.
    :return: Reminder naming what drifted, or None when the pair matches.
    """
    if meta_text is None:
        return (
            f"Meta companion missing: create {meta_path} beside {doc_path}. "
            "Mirror every line of the doc at the same line number, keeping each line's indentation and markers "
            "(heading, list, quote, fence) and write the reasoning behind each changed line on its meta line. "
            "When the doc was already committed, land a prose-free skeleton of the committed doc as its own commit "
            "ahead of this change, so the change's meta diff shows only its reasoning lines."
        )

    doc_count = len(doc_text.splitlines())
    meta_count = len(meta_text.splitlines())
    mismatches = find_mismatches(doc_text, meta_text)
    if doc_count == meta_count and not mismatches:
        return None

    problems: list[str] = []
    if doc_count != meta_count:
        problems.append(f"{doc_path} has {doc_count} lines but {meta_path} has {meta_count}")
    if mismatches:
        listed = ", ".join(str(number) for number in mismatches[:MAX_REPORTED_LINES])
        if len(mismatches) > MAX_REPORTED_LINES:
            listed += f" and {len(mismatches) - MAX_REPORTED_LINES} more"
        problems.append(f"line format differs at line {listed}")

    return (
        f"Meta companion out of step: {'; '.join(problems)}. "
        "Realign the meta so line N explains line N of the doc with the same indentation and markers "
        "and update the reasoning for any line the edit changed."
    )


def find_credits(meta_text: str) -> list[int]:
    """
    Returns the 1-based numbers of the meta lines that credit or date their reasoning.

    :param meta_text: Full content of the `.meta.md` file.
    :return: Line numbers matching any of `CREDIT_PATTERNS`, in file order.
    """
    credited: list[int] = []
    for number, line in enumerate(meta_text.splitlines(), start=1):
        for pattern in CREDIT_PATTERNS:
            if pattern.search(line):
                credited.append(number)
                break

    return credited


def describe_credits(meta_path: str, meta_text: str | None) -> str | None:
    """
    Returns the reminder text for credited or dated reasoning, or None when there is none.

    :param meta_path: Path of the `.meta.md` file.
    :param meta_text: Content of the `.meta.md` file, or None when it is missing.
    :return: Reminder naming the offending lines, or None when every line states only its reason.
    """
    if meta_text is None:
        return None

    credited = find_credits(meta_text)
    if not credited:
        return None

    listed = ", ".join(str(number) for number in credited[:MAX_REPORTED_LINES])
    if len(credited) > MAX_REPORTED_LINES:
        listed += f" and {len(credited) - MAX_REPORTED_LINES} more"

    return (
        f"Meta reasoning credited or dated at line {listed} of {meta_path}. "
        "State the reason itself and drop who gave it (stated by the user, the user ruled) and when (a date): "
        "every line is the user's rule and git history records the date."
    )


def read_text(path: str) -> str | None:
    """
    Returns a file's content, or None when it can't be read.

    :param path: File to read.
    :return: Decoded content, or None when the file is missing or unreadable.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return None


def build_reminder(context: str) -> dict[str, dict[str, str]]:
    """
    Builds the hook output carrying the reminder.

    :param context: Reminder text for Claude.
    :return: Hook output object ready to serialize to stdout.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    }


def main() -> None:
    """Read the hook payload on stdin and print a reminder when a markdown pair drifts."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return

    if not isinstance(payload, dict) or payload.get("tool_name") not in ("Edit", "Write"):
        return

    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return

    file_path = tool_input.get("file_path")
    if not isinstance(file_path, str):
        return

    paths = pair_paths(os.path.expanduser(file_path))
    if paths is None:
        return

    doc_path, meta_path = paths
    doc_text = read_text(doc_path)
    if doc_text is None:
        return

    meta_text = read_text(meta_path)
    reminders: list[str] = []
    drift = describe_drift(doc_path, meta_path, doc_text, meta_text)
    if drift is not None:
        reminders.append(drift)

    credit = describe_credits(meta_path, meta_text)
    if credit is not None:
        reminders.append(credit)

    if not reminders:
        return

    json.dump(build_reminder(" ".join(reminders)), sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
