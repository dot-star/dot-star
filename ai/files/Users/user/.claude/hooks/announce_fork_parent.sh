#!/usr/bin/env bash
#
# SessionStart hook: tell a session opened by fork_session_into_new_window.sh
# which session it forked from and where that transcript lives. Fires on a
# fresh start only; a `/clear` or resume inside the fork inherits the same
# environment and would otherwise announce the parent again.

set -euo pipefail

input=$(cat)
source_event=$(command jq --raw-output '.source // empty' <<<"${input}")

if [ -z "${CLAUDE_FORKED_FROM:-}" ] || [ "${source_event}" != "startup" ]; then
    exit 0
fi

context="This session was forked from session ${CLAUDE_FORKED_FROM} to take on a side task while that session carries on."
context+=" Its transcript is at ${CLAUDE_FORKED_TRANSCRIPT:-an unknown path} (JSONL, one event per line)."
context+=" Read it only as far as the task needs: the user's references to earlier work (that file, the bug we found) point there."

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}'
