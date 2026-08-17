#!/usr/bin/env python3
"""
Stop hook: flag a comma before "and" that joins just two things.

Per ~/.claude/CLAUDE.md (Output > drop the comma before `and`), a comma stays
before "and" only when it closes a list of three or more. Scan the last turn's
prose for `, and` and block so Claude drops the comma before re-sending.

Distinguishing the two cases needs one signal: an earlier comma in the same
segment. "a, b, and c" has one and is legitimate; "Do X, and do Y" has none.
Commas that open a subordinate clause (`, so`, `, though`, `, which`) don't
count, since they mark a clause boundary rather than a list item, which is
exactly the shape that hides a two-item join behind an earlier comma.

Code spans, fenced blocks, and blockquotes are stripped first: quoted material
carries the author's punctuation and a comma inside code is syntax. Like
`check_acronyms.py`, the heuristic biases toward false-negatives to keep
friction low.

Usage:
    Wired as a Stop hook in settings.json; reads the hook payload as JSON on
    stdin and prints a block decision on stdout when it finds an offender.

Example:
    echo '{"last_assistant_message": "Do X, and do Y."}' | check_comma_before_and.py
"""

import json
import re
import sys

# Treat a comma followed by one of these as a clause boundary, not a list item.
# "..., so they double up, and it never confirms" reads as two things joined,
# even though a comma precedes the "and".
CLAUSE_CONNECTORS = {
    "after",
    "although",
    "and",
    "as",
    "because",
    "before",
    "but",
    "however",
    "if",
    "or",
    "since",
    "so",
    "then",
    "therefore",
    "though",
    "unless",
    "until",
    "when",
    "where",
    "which",
    "while",
    "who",
    "whom",
    "whose",
    "yet",
}

# Split prose into the units a list can live in. A list never spans a sentence
# terminator, semicolon, colon, or line break, so each is a hard boundary.
SEGMENT_BOUNDARY = re.compile(r"[.!?;:\n]+")

COMMA_BEFORE_AND = re.compile(r",\s+and\b")

# Show this many characters on each side of the offending comma so the excerpt
# carries enough context to spot the join without quoting the whole segment.
EXCERPT_LEADING = 60
EXCERPT_TRAILING = 30


def strip_exempt(text):
    """Drops regions where the comma isn't Claude's own prose: code and quoted material."""

    # Strip fenced code blocks first so their contents don't survive as prose.
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)

    # Drop blockquote lines; quoted content carries the author's punctuation.
    kept_lines = [line for line in text.splitlines() if not re.match(r"\s*>", line)]
    text = "\n".join(kept_lines)

    # Strip inline code spans; a comma there is syntax, not prose.
    text = re.sub(r"`[^`]*`", " ", text)

    return text


def has_list_comma(prefix):
    """Returns True when an earlier comma in the segment opens a list of three or more."""
    for match in re.finditer(r",\s*(\w+)", prefix):
        if match.group(1).lower() in CLAUSE_CONNECTORS:
            continue
        return True
    return False


def build_excerpt(segment, comma_start, comma_end):
    """Returns a one-line window around the offending comma, ellipsis-free."""
    start = max(0, comma_start - EXCERPT_LEADING)
    end = min(len(segment), comma_end + EXCERPT_TRAILING)
    return " ".join(segment[start:end].split())


def find_offenders(prose):
    """Returns excerpts around each two-item `, and`, in order, deduped."""
    offenders = []
    seen = set()
    for segment in SEGMENT_BOUNDARY.split(prose):
        for match in COMMA_BEFORE_AND.finditer(segment):
            if has_list_comma(segment[: match.start()]):
                continue
            excerpt = build_excerpt(segment, match.start(), match.end())
            if excerpt in seen:
                continue
            seen.add(excerpt)
            offenders.append(excerpt)

    return offenders


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    if data.get("stop_hook_active"):
        return 0

    msg = data.get("last_assistant_message") or ""
    if not msg:
        return 0

    offenders = find_offenders(strip_exempt(msg))
    if not offenders:
        return 0

    reason = (
        'Your last message puts a comma before "and" where it joins just two things '
        "(per ~/.claude/CLAUDE.md Output > drop the comma before `and`):\n"
        + "\n".join("  " + offender for offender in offenders)
        + "\n"
        "\n┌─ 🤖 for Claude ──────────────────────────────────────"
        "\n│ Delete the comma unless it closes a list of three or"
        "\n│ more. Re-send."
        "\n└──────────────────────────────────────────────────────"
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
