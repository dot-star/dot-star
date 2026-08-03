#!/usr/bin/env bash
#
# UserPromptSubmit hook: inject the current wall-clock time on every prompt.
# The harness stamps `currentDate` once at session start and never refreshes it,
# so a session resumed days later reasons off a stale date while still sounding
# certain. Re-stating the time each prompt makes the right value unavoidable
# rather than something Claude has to first suspect is wrong and go check.

set -euo pipefail

# Drain the hook's JSON payload. Nothing here reads it, but leaving stdin
# unconsumed can hand the harness a broken pipe.
cat >/dev/null

now=$(date)

command jq \
    --null-input \
    --compact-output \
    --arg context "Current time: ${now} (supersedes the session-start currentDate, which goes stale on resume)." \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $context}}'
