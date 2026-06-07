#!/usr/bin/env python3
"""
Stop hook: flag unexplained niche acronyms in the last assistant message.

Per ~/.claude/CLAUDE.md (Output > spell out niche acronyms), prose should spell
out insider acronyms and keep only the skim-without-expansion set (API, AWS,
URL, PR). Scan the last turn's prose for all-caps tokens of 2+ letters that are
neither whitelisted nor a plain English word, and block so Claude spells them
out before re-sending.

Code spans, fenced blocks, and blockquotes are stripped first: acronyms inside
code identifiers or quoted material are legitimately exempt. The dictionary
check absorbs all-caps emphasis words (NEVER, IMPORTANT) without whitelisting
each, and biases toward false-negatives over false-positives to keep friction
low.

Usage:
    Wired as a Stop hook in settings.json; reads the hook payload as JSON on
    stdin and prints a block decision on stdout when it finds an offender.

Example:
    echo '{"last_assistant_message": "Check the FAB."}' | check_acronyms.py
"""

import json
import re
import sys

# Whitelist acronyms a reader skims without expansion. Extend as needed; the
# dictionary check below already covers all-caps English words, so list only
# true acronyms.
WHITELIST = {
    # Keep CLAUDE.md's named set.
    "API",
    "AWS",
    "PR",
    "URL",
    # Keep broadly skimmable tech and web terms.
    "CLI",
    "CPU",
    "CSS",
    "GPU",
    "HTML",
    "HTTP",
    "HTTPS",
    "ID",
    "JSON",
    "OS",
    "RAM",
    "SDK",
    "SQL",
    "SSH",
    "UI",
    "URI",
    "USB",
    "UX",
    # Keep common abbreviations.
    "AM",
    "OK",
    "PM",
    "TODO",
    # Keep roman numerals.
    "II",
    "III",
    "IV",
    "IX",
    "VI",
    "VII",
    "VIII",
    "XI",
    "XII",
}

DICT_PATH = "/usr/share/dict/words"


def load_dictionary():
    """Returns the lowercased system word list, or an empty set if unavailable."""
    try:
        with open(DICT_PATH, encoding="utf-8", errors="ignore") as words:
            return {line.strip().lower() for line in words}
    except OSError:
        return set()


def strip_exempt(text):
    """Drops regions where acronyms are allowed: code and quoted material."""

    # Strip fenced code blocks first so their contents don't survive as prose.
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)

    # Drop blockquote lines; quoted content carries the author's acronyms.
    kept_lines = [line for line in text.splitlines() if not re.match(r"\s*>", line)]
    text = "\n".join(kept_lines)

    # Strip inline code spans; the acronym would be a code identifier there.
    text = re.sub(r"`[^`]*`", " ", text)

    return text


def find_offenders(prose, dictionary):
    """Returns unexplained acronyms in order, deduped."""
    offenders = []
    seen = set()
    for token in re.findall(r"\b[A-Z]{2,}\b", prose):
        if token in WHITELIST:
            continue
        if token.lower() in dictionary:
            continue
        if token in seen:
            continue
        seen.add(token)
        offenders.append(token)

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

    offenders = find_offenders(strip_exempt(msg), load_dictionary())
    if not offenders:
        return 0

    reason = (
        "Your last message uses unexplained acronym(s) in prose "
        "(per ~/.claude/CLAUDE.md Output > spell out niche acronyms): "
        + ", ".join(offenders)
        + "\n\n🤖 `[for Claude]` Spell each out on first use (e.g. \"floating "
        "action button (FAB)\"), or add it to WHITELIST in check_acronyms.py "
        "if it is truly skim-without-expansion, then re-send."
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
