#!/usr/bin/env bash
#
# UserPromptSubmit hook: point at the status shorthand rule whenever a prompt
# mentions `sta` anywhere, not just as a bare one-token message. CLAUDE.md's
# shorthand table fires only on an exact whole-message match, so a mention
# carrying any other words reads as ordinary prose. Emit a pointer rather than
# the rule text, keeping CLAUDE.md the single source.

set -euo pipefail

input=$(cat)
prompt=$(command jq --raw-output '.prompt // empty' <<<"${input}")

if [ -z "${prompt}" ]; then
    exit 0
fi

# Lowercase the prompt for case-insensitive matching.
prompt_lower=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')

# Spell the word boundaries out. \b is GNU-only and [[:<:]] is BSD-only, where
# dot-star runs on both macOS and Ubuntu.
if [[ ! "${prompt_lower}" =~ (^|[^[:alnum:]_])sta([^[:alnum:]_]|$) ]]; then
    exit 0
fi

context='The prompt mentions "sta": apply the `s`/`st`/`sta` status shorthand from CLAUDE.md, even though the message is not the bare token.'

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $context}}'
