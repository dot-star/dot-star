#!/usr/bin/env python3
"""
Stop hook: flag unexplained niche acronyms in the last assistant message.

Per ~/.claude/CLAUDE.md (Output > spell out niche acronyms), prose should spell
out insider acronyms and keep only the skim-without-expansion set (API, AWS,
URL, PR). Scan the last turn's prose for all-caps tokens of 2-5 letters that are
neither whitelisted nor a plain English word, and block so Claude spells them
out before re-sending. Longer all-caps runs are file names (README, CHANGELOG)
or emphasis rather than acronyms, so they pass.

Code spans, fenced blocks, and blockquotes are stripped first: acronyms inside
code identifiers or quoted material are legitimately exempt. The dictionary
check absorbs all-caps emphasis words (NEVER, IMPORTANT) without whitelisting
each, and biases toward false-negatives over false-positives to keep friction
low.

Mixed-case insider acronyms (IaC, IoT) escape the all-caps scan, so a small
explicit flag-list catches those by exact match; a generic mixed-case pattern
would snag CamelCase identifiers and product names (GitHub, JavaScript).

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
# true acronyms. List a hyphenated compound whole when its parts are niche alone.
WHITELIST = {
    "AM",
    "API",
    "AWS",
    "BSD",
    "CD-ROM",
    "CDK",
    "CI",
    "CLI",
    "CORS",
    "CPU",
    "CSS",
    "CSV",
    "CWS",
    "DM",
    "EDT",
    "EST",
    "ET",
    "FAQ",
    "FINRA",
    "GNU",
    "GPU",
    "HTML",
    "HTTP",
    "HTTPS",
    "ID",
    "II",
    "III",
    "IP",
    "IV",
    "IX",
    "JSON",
    "JSONL",
    "KB",
    "KYC",
    "LLC",
    "MB",
    "OK",
    "OS",
    "PDF",
    "PHP",
    "PM",
    "PR",
    "PRD",
    "PTAL",
    "QA",
    "QR",
    "RAM",
    "RSVP",
    "SDK",
    "SPCX",
    "SQL",
    "SSH",
    "TBD",
    "TDD",
    "TODO",
    "TOML",
    "UI",
    "URI",
    "URL",
    "USB",
    "UTC",
    "UX",
    "VI",
    "VII",
    "VIII",
    "XI",
    "XII",
    "YAML",
}

# Flag mixed-case insider acronyms the all-caps scan misses (an embedded
# lowercase connector breaks the run); a generic mixed-case pattern would snag
# CamelCase identifiers and product names. Match exactly; extend as needed.
MIXED_CASE_FLAG = {
    "IaC",
    "IaaS",
    "IoT",
    "PaaS",
    "QoS",
    "SaaS",
}

DICT_PATH = "/usr/share/dict/words"

# Cap the scan at the length real acronyms run to; past it an all-caps token is
# a file name (README, CHANGELOG) or emphasis, not an acronym to spell out.
MAX_ACRONYM_LENGTH = 5


def load_dictionary() -> set[str]:
    """Returns the lowercased system word list, or an empty set if unavailable."""
    try:
        with open(DICT_PATH, encoding="utf-8", errors="ignore") as words:
            return {line.strip().lower() for line in words}
    except OSError:
        return set()


def strip_exempt(text: str) -> str:
    """Drops regions where acronyms are allowed: code and quoted material."""

    # Strip fenced code blocks first so their contents don't survive as prose.
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)

    # Drop blockquote lines; quoted content carries the author's acronyms.
    kept_lines = [line for line in text.splitlines() if not re.match(r"\s*>", line)]
    text = "\n".join(kept_lines)

    # Strip inline code spans; the acronym would be a code identifier there.
    text = re.sub(r"`[^`]*`", " ", text)

    # Strip Jira issue keys; the project prefix is an identifier, not prose.
    text = re.sub(r"\b[A-Z]{2,}-\d+\b", " ", text)

    return text


def find_tokens(prose: str) -> list[str]:
    """Returns all-caps tokens, keeping a whitelisted hyphenated compound whole."""
    part = r"[A-Z]{2," + str(MAX_ACRONYM_LENGTH) + r"}"
    tokens = []
    for compound, plural in re.findall(r"\b(" + part + r"(?:-" + part + r")*)(s?)\b", prose):
        parts = compound.split("-")
        if compound in WHITELIST:
            tokens.append(compound)
        elif plural:
            # Skip the last part: its trailing "s" hid it from the scan, as with a lone plural (APIs).
            tokens.extend(parts[:-1])
        else:
            tokens.extend(parts)
    return tokens


def find_offenders(prose: str, dictionary: set[str]) -> list[str]:
    """Returns unexplained acronyms in order, deduped."""
    offenders = []
    seen = set()
    for token in find_tokens(prose):
        if token in WHITELIST:
            continue
        if token.lower() in dictionary:
            continue
        if token in seen:
            continue
        seen.add(token)
        offenders.append(token)

    # Catch mixed-case insider acronyms the all-caps scan can't see. Sort for a
    # deterministic order when several appear in one message.
    for token in sorted(MIXED_CASE_FLAG):
        if token in seen:
            continue
        if re.search(r"\b" + re.escape(token) + r"\b", prose):
            seen.add(token)
            offenders.append(token)

    return offenders


def main() -> int:
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
        "(per ~/.claude/CLAUDE.md Output > spell out niche acronyms): " + ", ".join(offenders) + "\n"
        "\n┌─ 🤖 for Claude ───────────────────────────────────────────────────────"
        "\n│ Reply with only the CLAUDE.md acronym table or whitelist [wl] them."
        "\n└───────────────────────────────────────────────────────────────────────"
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
