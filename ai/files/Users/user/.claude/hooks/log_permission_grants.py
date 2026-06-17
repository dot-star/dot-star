#!/usr/bin/env python3
"""
Snapshot a worktree's accumulated permission rules before it is torn down.

A worktree's `.claude/settings.local.json` holds the allow/deny/ask rules
accreted while working in it; `git worktree remove` (and the ExitWorktree tool)
delete that file along with the worktree. This script appends a snapshot to a
growing JSON Lines file at `~/.claude/permission-grants.jsonl`, the durable
counterpart to the ask-stream in `~/.claude/permission-requests.jsonl`.

Usage:
    Shell mode (the `wtd` / git_worktree_done teardown):
        log_permission_grants.py --worktree <path> [--reason <reason>]
    Hook mode (wired as a PreToolUse hook matching ExitWorktree):
        Reads the event JSON on stdin and archives only a remove-action
        request, taking the worktree path from the request cwd.
"""

import argparse
import datetime
import fcntl
import json
import os
import re
import subprocess
import sys

LOG_PATH = os.path.expanduser("~/.claude/permission-grants.jsonl")

# Matches common token patterns (e.g., GitHub tokens) and inline URL credentials
CREDENTIAL_PATTERNS = [
    (re.compile(r"ghp_[a-zA-Z0-9]{36}"), "<REDACTED_GITHUB_TOKEN>"),
    (re.compile(r"https://[^:\s]+:[^@\s]+@"), "https://<REDACTED_CREDENTIALS>@"),
]


def sanitize(rule: str) -> str:
    """Masks known credential and token formats in a single rule string."""
    for pattern, replacement in CREDENTIAL_PATTERNS:
        rule = pattern.sub(replacement, rule)
    return rule


def sanitize_permissions(settings: dict) -> dict:
    """Masks credentials in every allow/deny/ask rule of a settings object."""
    permissions = settings.get("permissions")
    if not isinstance(permissions, dict):
        return settings

    for key in ("allow", "deny", "ask"):
        rules = permissions.get(key)
        if isinstance(rules, list):
            permissions[key] = [sanitize(r) if isinstance(r, str) else r for r in rules]
    return settings


def worktree_branch(worktree: str) -> str:
    """Returns the worktree's current branch, or "" when it can't be read."""
    try:
        result = subprocess.run(
            ["git", "-C", worktree, "symbolic-ref", "--quiet", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return ""

    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def load_settings(settings_path: str):
    """Returns the parsed settings.local.json, or None when absent/empty/invalid."""
    try:
        with open(settings_path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return None

    if not text.strip():
        return None

    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return None


def build_entry(worktree: str, reason: str, timestamp: str, session_id: str = ""):
    """Pairs the worktree's settings snapshot with teardown metadata, or None."""
    settings_path = os.path.join(worktree, ".claude", "settings.local.json")
    settings = load_settings(settings_path)
    if settings is None:
        return None

    return {
        "settings": sanitize_permissions(settings),
        "metadata": {
            "timestamp": timestamp,
            "worktree": worktree,
            "branch": worktree_branch(worktree),
            "settings_path": settings_path,
            "reason": reason,
            "session_id": session_id,
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


def hook_worktree(payload: dict):
    """Returns the worktree to archive for a remove-action ExitWorktree, else None."""
    if payload.get("tool_name") != "ExitWorktree":
        return None

    tool_input = payload.get("tool_input") or {}
    if tool_input.get("action") != "remove":
        return None

    return payload.get("cwd") or None


def parse_args(argv: list) -> argparse.Namespace:
    """Parses the shell-mode flags; both are absent in hook mode."""
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--worktree")
    parser.add_argument("--reason", default="wtd")
    return parser.parse_args(argv)


def main(argv: list) -> None:
    """Archive the worktree's settings, taking the path from a flag or stdin."""
    args = parse_args(argv)
    timestamp = datetime.datetime.now().astimezone().isoformat()

    # Take the path straight from the teardown function in shell mode.
    if args.worktree:
        entry = build_entry(args.worktree, args.reason, timestamp)
    else:
        try:
            payload = json.load(sys.stdin)
        except (json.JSONDecodeError, ValueError):
            return

        if not isinstance(payload, dict):
            return

        worktree = hook_worktree(payload)
        if not worktree:
            return

        entry = build_entry(
            worktree,
            "ExitWorktree",
            timestamp,
            session_id=payload.get("session_id") or "",
        )

    if entry is not None:
        append_entry(entry)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Exception as e:
        # Prevent runtime telemetry failures from breaking Claude UI, but log to stderr for diagnostics
        print(f"Archive hook exception: {e}", file=sys.stderr)
