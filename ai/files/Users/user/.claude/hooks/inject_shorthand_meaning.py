#!/usr/bin/env python3
"""
UserPromptSubmit hook: inject the shorthand entry a prompt invokes.

The shorthand table lives in `ai/contexts/shorthand.md` instead of the
always-on `~/.claude/CLAUDE.md`, so its cost is paid only by the prompt that
uses a token. Match the whole prompt against the Whole-message tokens section,
else match each `;`-separated clause against that section and scan the prompt
for the In-message tokens, and inject each matched entry verbatim.

A bracket option offered in the last assistant message outranks the table
(`n` after a `[n]ow` offer means now, not no), so a prompt naming one injects
that note instead of the table's meaning. Any failure injects a pointer at the
doc rather than nothing: a silent miss would quietly break every shorthand.

With `--index`, run as a SessionStart hook instead: inject a compact index of
every token with a short meaning, so a token used mid-sentence (where the
prompt-time match stays silent) is still recognized and its entry looked up.
The index is also written to `shorthand_index.md` in the session tmp dir, so
what loaded can be inspected.

Usage:
    Wired as a UserPromptSubmit hook and, with `--index`, a SessionStart hook
    in settings.json; reads the hook payload as JSON on stdin and prints the
    injected context on stdout. Set `CLAUDE_CONTEXTS_DIR` to read the doc from
    another checkout.

Example:
    echo '{"prompt": "play"}' | inject_shorthand_meaning.py
    echo '{"session_id": "12345678"}' | inject_shorthand_meaning.py --index
"""

import json
import os
import re
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from dataclasses import field
from typing import Any

from claude_session_dir import claude_session_dir

DOC_NAME = "shorthand.md"
INDEX_NAME = "shorthand_index.md"
INDEX_FLAG = "--index"

# Cap each index meaning: long enough to tell tokens apart, short enough that
# 50-odd entries stay a small fraction of the hook's 10,000-character cap.
INDEX_MEANING_CHARS = 60
QUOTED_MEANING_PATTERN = re.compile(r'^"([^"]+)"')
# End an unquoted meaning at the entry's first colon or sentence break.
MEANING_END_PATTERN = re.compile(r":|\.\s")

WHOLE_MESSAGE_HEADING = "## Whole-message tokens"
IN_MESSAGE_HEADING = "## In-message tokens"

# Read a prompt opening on one of these as a question about a token, not a use.
QUESTION_WORDS = {
    "are",
    "can",
    "could",
    "do",
    "does",
    "how",
    "is",
    "should",
    "what",
    "when",
    "where",
    "which",
    "who",
    "why",
    "will",
    "would",
}

# Stop the token list at the entry's verb; backticks after it are prose.
MEAN_PATTERN = re.compile(r"\smeans?\s")
TOKEN_PATTERN = re.compile(r"`([^`]+)`")
PLACEHOLDER_PATTERN = re.compile(r"(<[^>]+>)")
MARKER_PATTERN = re.compile(r"^\s*<!--\s*shorthand-match:\s*(.+?)\s*-->\s*$")

# Find bracket options the way menus render them: a code span opening on `[`.
OFFERED_OPTION_PATTERN = re.compile(r"`\[([^\]`\s]+)\]")
CODE_SPAN_PATTERN = re.compile(r"`[^`]*`")

# Read only the transcript's tail; it runs to megabytes and runs on every prompt.
TRANSCRIPT_TAIL_BYTES = 4 * 1024 * 1024


@dataclass
class Entry:
    """Holds one shorthand entry: its text and the patterns that invoke it."""

    text: str
    tokens: list[str] = field(default_factory=list)
    patterns: list[re.Pattern[str]] = field(default_factory=list)


def doc_path() -> str:
    """Returns the shorthand doc's path, honoring `CLAUDE_CONTEXTS_DIR`."""
    contexts_dir = os.environ.get("CLAUDE_CONTEXTS_DIR", os.path.expanduser("~/.dot-star/ai/contexts"))
    return os.path.realpath(os.path.join(contexts_dir, DOC_NAME))


def token_to_pattern(token: str, whole_message: bool) -> re.Pattern[str]:
    """
    Compiles a backticked token into a case-insensitive pattern.

    :param token: Token as written in the doc (e.g. "exp <x>", "<N> iter").
    :param whole_message: True anchors the pattern to the whole prompt; False
        matches the token as a standalone word anywhere in it.
    :return: Compiled pattern.
    """
    parts = []
    for piece in PLACEHOLDER_PATTERN.split(token):
        if piece == "<N>":
            parts.append(r"\d+")
        elif PLACEHOLDER_PATTERN.fullmatch(piece):
            parts.append(r".+")
        else:
            parts.append(r"\s+".join(re.escape(word) for word in piece.split(" ")))
    body = "".join(parts)
    if whole_message:
        return re.compile(rf"^{body}$", re.IGNORECASE)
    else:
        return re.compile(rf"(?<!\w){body}(?!\w)", re.IGNORECASE)


def parse_section(lines: Iterable[str], whole_message: bool) -> list[Entry]:
    """
    Splits a section's lines into entries, one per top-level bullet.

    :param lines: Section body, heading excluded.
    :param whole_message: Whether the section's tokens match the whole prompt.
    :return: Entries in doc order.
    """
    entries: list[Entry] = []
    for line in lines:
        if line.startswith("- "):
            lead = MEAN_PATTERN.split(line, maxsplit=1)[0]
            tokens = TOKEN_PATTERN.findall(lead)
            entry = Entry(text=line, tokens=tokens)
            for token in tokens:
                entry.patterns.append(token_to_pattern(token, whole_message))
            entries.append(entry)
        elif not entries:
            # Skip the section's intro prose above its first entry.
            continue
        elif marker := MARKER_PATTERN.match(line):
            entries[-1].patterns.append(re.compile(marker.group(1), re.IGNORECASE))
        else:
            entries[-1].text += "\n" + line
    for entry in entries:
        entry.text = entry.text.rstrip()
    return entries


def parse_doc(text: str) -> tuple[list[Entry], list[Entry]]:
    """
    Parses the shorthand doc into its two sections' entries.

    :param text: Full doc text.
    :return: Whole-message entries, then in-message entries.
    :raises ValueError: When either section heading is missing.
    """
    sections: dict[str, list[str]] = {}
    current = None
    for line in text.split("\n"):
        if line.startswith("## "):
            current = line.strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    for heading in (WHOLE_MESSAGE_HEADING, IN_MESSAGE_HEADING):
        if heading not in sections:
            raise ValueError(f"missing section {heading!r}")
    whole = parse_section(sections[WHOLE_MESSAGE_HEADING], whole_message=True)
    in_message = parse_section(sections[IN_MESSAGE_HEADING], whole_message=False)
    return whole, in_message


def last_assistant_text(transcript_path: str) -> str:
    """
    Returns the text of the last assistant message in a transcript.

    :param transcript_path: Path to the session's transcript, one JSON record
        per line. Returns "" when the file is missing or holds no text.
    :return: Text blocks of the newest assistant record that carries any.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return ""
    with open(transcript_path, "rb") as transcript:
        transcript.seek(max(0, os.path.getsize(transcript_path) - TRANSCRIPT_TAIL_BYTES))
        tail = transcript.read().decode("utf-8", errors="replace")
    for line in reversed(tail.split("\n")):
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if record.get("type") != "assistant":
            continue
        content = record.get("message", {}).get("content")
        if not isinstance(content, list):
            continue
        texts = []
        for block in content:
            if block.get("type") == "text":
                texts.append(block.get("text", ""))
        if texts:
            return "\n".join(texts)
    return ""


def offered_options(message: str) -> set[str]:
    """
    Returns the lowercased bracket tokens a message offered.

    :param message: Assistant message text (e.g. a menu with **`[n]ow`**).
    :return: Bracket contents (e.g. {"n", "c1"}).
    """
    options = set()
    for token in OFFERED_OPTION_PATTERN.findall(message):
        options.add(token.lower())
    return options


def match_whole(prompt: str, entries: Iterable[Entry]) -> list[Entry]:
    """
    Returns the entries whose patterns match the whole prompt.

    :param prompt: Stripped prompt text.
    :param entries: Whole-message entries.
    :return: Matched entries in doc order.
    """
    first_word = prompt.split(" ", 1)[0].lower()
    if first_word in QUESTION_WORDS:
        return []
    matched = []
    for entry in entries:
        for pattern in entry.patterns:
            if pattern.search(prompt):
                matched.append(entry)
                break
    return matched


def match_clauses(prompt: str, entries: Iterable[Entry], transcript_path: str) -> list[Entry]:
    """
    Returns the whole-message entries matched by a `;`-separated clause.

    :param prompt: Stripped prompt text (e.g. "undo; gen the example"). Code
        spans are skipped, so a `;` quoted in backticks never splits a clause.
    :param entries: Whole-message entries.
    :param transcript_path: Session transcript; a clause naming a bracket option
        its last message offered picks that option, so it matches no entry.
    :return: Matched entries in doc order of first match, without repeats.
    """
    prose = CODE_SPAN_PATTERN.sub(" ", prompt)
    if ";" not in prose:
        return []
    offered = offered_options(last_assistant_text(transcript_path))
    matched: list[Entry] = []
    for raw_clause in prose.split(";"):
        clause = raw_clause.strip()
        if not clause or clause.lower() in offered:
            continue
        for entry in match_whole(clause, entries):
            if entry not in matched:
                matched.append(entry)
    return matched


def match_in_message(prompt: str, entries: Iterable[Entry]) -> list[Entry]:
    """
    Returns the entries whose tokens appear as words inside the prompt.

    :param prompt: Stripped prompt text. Code spans are skipped, since a token
        quoted in backticks is being discussed rather than used.
    :param entries: In-message entries.
    :return: Matched entries in doc order.
    """
    prose = CODE_SPAN_PATTERN.sub(" ", prompt)
    matched = []
    for entry in entries:
        for pattern in entry.patterns:
            if pattern.search(prose):
                matched.append(entry)
                break
    return matched


def build_context(prompt: str, transcript_path: str, path: str) -> str:
    """
    Builds the context to inject for a prompt.

    :param prompt: Raw prompt text.
    :param transcript_path: Session transcript, read for offered bracket options.
    :param path: Shorthand doc path.
    :return: Context to inject, or "" when the prompt uses no shorthand.
    """
    prompt = prompt.strip()
    if not prompt:
        return ""
    with open(path, encoding="utf-8") as doc:
        whole_entries, in_message_entries = parse_doc(doc.read())

    whole = match_whole(prompt, whole_entries)
    if whole:
        if prompt.lower() in offered_options(last_assistant_text(transcript_path)):
            return f"Shorthand: `{prompt}` picks the `[{prompt}]` option your last message offered; a bracket offer outranks the shorthand table, so ignore the table's meaning for it."
        else:
            header = f"Shorthand: the whole prompt `{prompt}` matches this entry in {path}; apply it:"
            return "\n\n".join([header] + [entry.text for entry in whole])
    elif " " not in prompt:
        return ""

    sections = []
    clauses = match_clauses(prompt, whole_entries, transcript_path)
    if clauses:
        header = f"Shorthand: clauses of the prompt match these whole-message entries in {path}; apply each:"
        sections.append("\n\n".join([header] + [entry.text for entry in clauses]))
    in_message = match_in_message(prompt, in_message_entries)
    if in_message:
        header = f"Shorthand: the prompt uses these in-message tokens from {path}; read each as its referent:"
        sections.append("\n\n".join([header] + [entry.text for entry in in_message]))
    return "\n\n".join(sections)


def short_meaning(entry: Entry) -> str:
    """
    Returns an entry's meaning, trimmed for the index.

    :param entry: Parsed entry (e.g. the `play` entry).
    :return: The quoted meaning when the entry opens with one (e.g. "play it
        out"), else the clause after `means` up to its first colon or sentence
        break, cut at a word boundary past `INDEX_MEANING_CHARS`.
    """
    first_line = entry.text.split("\n", 1)[0]
    parts = MEAN_PATTERN.split(first_line, maxsplit=1)
    if len(parts) < 2:
        return ""
    rest = parts[1].strip()
    quoted = QUOTED_MEANING_PATTERN.match(rest)
    if quoted:
        meaning = quoted.group(1)
    else:
        meaning = MEANING_END_PATTERN.split(rest, maxsplit=1)[0].strip()
    if len(meaning) <= INDEX_MEANING_CHARS:
        return meaning
    return meaning[:INDEX_MEANING_CHARS].rsplit(" ", 1)[0].rstrip(",;") + "..."


def index_lines(entries: Iterable[Entry]) -> list[str]:
    """
    Renders one index line per entry.

    :param entries: Entries of one section, in doc order.
    :return: Lines like "- `play`: play it out".
    """
    lines = []
    for entry in entries:
        tokens = ", ".join(f"`{token}`" for token in entry.tokens)
        lines.append(f"- {tokens}: {short_meaning(entry)}")
    return lines


def build_index(path: str) -> str:
    """
    Builds the session-start index of every shorthand token.

    :param path: Shorthand doc path.
    :return: Index text: a lead line stating the rule, then one line per entry
        under a heading per section.
    """
    with open(path, encoding="utf-8") as doc:
        whole_entries, in_message_entries = parse_doc(doc.read())
    lines = [
        f"Shorthand index: read each token below as shorthand wherever it appears in a prompt, mid-sentence included, when the words around it use it that way. When a prompt uses one and no shorthand hook context explained it, read {path} for its full entry before answering.",
        "",
        "Whole-message tokens (fire alone or as a `;` clause; look up a mid-sentence use):",
        *index_lines(whole_entries),
        "",
        "In-message tokens (fire anywhere in a prompt):",
        *index_lines(in_message_entries),
    ]
    return "\n".join(lines)


def write_index(session_id: str, context: str) -> None:
    """
    Writes the injected index to the session tmp dir for inspection.

    :param session_id: Raw session id from the hook payload; nothing is written
        when it is empty.
    :param context: Text the hook injects.
    """
    session_dir = claude_session_dir(session_id)
    if session_dir is None:
        return
    # Create the dir here too: SessionStart hooks run in parallel, so the dir's creator may not have run yet.
    session_dir.mkdir(parents=True, exist_ok=True)
    (session_dir / INDEX_NAME).write_text(context + "\n", encoding="utf-8")


def main_index() -> None:
    """Reads the SessionStart payload, then injects and writes the shorthand index."""
    path = doc_path()
    payload: dict[str, Any] = json.load(sys.stdin)
    try:
        context = build_index(path)
    except (OSError, ValueError, re.error) as error:
        context = f"Shorthand index failed ({error}); read {path} for the shorthand tokens before reading a short word in a prompt as plain text."
    try:
        write_index(payload.get("session_id") or "", context)
    except OSError:
        # Inject the index even when the inspection copy can't be written.
        pass
    output = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}}
    print(json.dumps(output))


def main() -> None:
    """Reads the hook payload, then prints the context to inject, if any."""
    if INDEX_FLAG in sys.argv[1:]:
        main_index()
        return
    path = doc_path()
    payload: dict[str, Any] = json.load(sys.stdin)
    try:
        context = build_context(payload.get("prompt") or "", payload.get("transcript_path") or "", path)
    except (OSError, ValueError, re.error) as error:
        context = f"Shorthand hook failed ({error}); read {path} to check whether this prompt uses shorthand."
    if not context:
        return
    output = {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": context}}
    print(json.dumps(output))


if __name__ == "__main__":
    main()
