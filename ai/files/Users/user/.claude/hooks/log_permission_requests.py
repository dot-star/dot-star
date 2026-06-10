#!/usr/bin/env python3
"""
PermissionRequest hook: log the permissions a request needed for later review.

Reads the hook event JSON on stdin and appends one entry per request to a growing
JSON Lines file at `~/.claude/permission-requests.jsonl`. Each entry is a valid,
single-line standard JSON object.

Usage:
    Wired in settings.json as a PermissionRequest hook with no matcher (all tools).
"""

import datetime
import fcntl
import json
import os
import re
import sys

LOG_PATH = os.path.expanduser("~/.claude/permission-requests.jsonl")

# Matches common token patterns (e.g., GitHub tokens) and inline URL credentials
CREDENTIAL_PATTERNS = [
    (re.compile(r"ghp_[a-zA-Z0-9]{36}"), "<REDACTED_GITHUB_TOKEN>"),
    (re.compile(r"https://[^:\s]+:[^@\s]+@"), "https://<REDACTED_CREDENTIALS>@"),
]


def sanitize_rules(rules: list) -> list:
    """Masks known credential and token formats in permission rules."""
    sanitized = []
    for rule in rules:
        cleaned = rule
        for pattern, replacement in CREDENTIAL_PATTERNS:
            cleaned = pattern.sub(replacement, cleaned)
        sanitized.append(cleaned)
    return sanitized


def synthesize_rule(payload: dict) -> str:
    """Builds a fallback permission rule when the payload carries no suggestions."""
    tool_name = payload.get("tool_name") or "UnknownTool"
    tool_input = payload.get("tool_input") or {}
    if tool_name == "Bash":
        command = (tool_input.get("command") or "").strip()
        if command:
            return f"Bash({command})"
    return tool_name


def extract_rules(payload: dict) -> list:
    """Returns Claude Code's suggested permission rules, or a synthesized fallback."""
    suggestions = payload.get("permission_suggestions") or []
    rules = []
    for suggestion in suggestions:
        if isinstance(suggestion, dict):
            rule = suggestion.get("rule")
        elif isinstance(suggestion, str):
            rule = suggestion
        else:
            rule = None

        if rule:
            rules.append(rule)

    if rules:
        return sanitize_rules(rules)
    else:
        return sanitize_rules([synthesize_rule(payload)])


def build_settings_path(cwd: str) -> str:
    """Returns the project-local settings file this request would be recorded in."""
    if not cwd:
        return ""

    return os.path.join(cwd, ".claude", "settings.local.json")


def build_entry(payload: dict, timestamp: str) -> dict:
    """Builds the log entry pairing the suggested allow rules with request metadata."""
    cwd = payload.get("cwd") or ""
    return {
        "permissions": {
            "allow": extract_rules(payload),
        },
        "metadata": {
            "timestamp": timestamp,
            "tool_name": payload.get("tool_name") or "",
            "cwd": cwd,
            "settings_path": build_settings_path(cwd),
            "session_id": payload.get("session_id") or "",
        },
    }


def append_entry(entry: dict, path: str = LOG_PATH) -> None:
    """Appends one entry as a single line, taking an exclusive lock for concurrency."""
    os.makedirs(os.path.dirname(path), exist_ok=True)

    # Opening in 'a' mode handles file creation atomically and prevents truncation races
    with open(path, "a", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            handle.write(json.dumps(entry) + "\n")
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def main() -> None:
    """Read the hook payload on stdin and append a log entry for the request."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return

    if not isinstance(payload, dict):
        return

    timestamp = datetime.datetime.now().astimezone().isoformat()
    append_entry(build_entry(payload, timestamp=timestamp))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Prevent runtime telemetry failures from breaking Claude UI, but log to stderr for diagnostics
        print(f"Logging hook exception: {e}", file=sys.stderr)
