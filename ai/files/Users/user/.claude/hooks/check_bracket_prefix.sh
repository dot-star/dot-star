#!/usr/bin/env bash
#
# Stop hook: enforce the bracket-prefix rule for inline-prose alternative
# questions (per ~/.claude/CLAUDE.md, Output > inline binary/ternary asks).
# Block when the last assistant message contains a ?-terminated sentence
# that offers alternatives (` or `) but lacks any `[x]remainder` accept-prefix
# token, and feed the violations back so Claude rewrites the question.

set -euo pipefail

input=$(cat)

# Avoid re-blocking once Claude is already re-running after a Stop block.
stop_hook_active=$(printf '%s' "${input}" |
    command jq --raw-output '.stop_hook_active // false')
if [ "${stop_hook_active}" = "true" ]; then
    exit 0
fi

msg=$(printf '%s' "${input}" |
    command jq --raw-output '.last_assistant_message // empty')
if [ -z "${msg}" ]; then
    exit 0
fi

# Strip fenced code blocks so `or` inside code samples doesn't trigger.
# Keep inline code spans intact because the `[x]remainder` token lives in `...`.
prose=$(printf '%s\n' "${msg}" |
    sed -E '/^```/,/^```/d')

# Walk each ?-terminated candidate sentence.
violations=()
while IFS= read -r sentence; do
    if [ -z "${sentence}" ]; then
        continue
    fi
    if ! printf '%s' "${sentence}" | grep --quiet --extended-regexp ' or '; then
        continue
    fi
    if printf '%s' "${sentence}" | grep --quiet --extended-regexp '\[[a-zA-Z]{1,3}\][a-zA-Z]'; then
        continue
    fi
    trimmed=$(printf '%s' "${sentence}" |
        tr -d '\n' |
        sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -n "${trimmed}" ]; then
        violations+=("${trimmed}")
    fi
done < <(printf '%s' "${prose}" |
    grep --only-matching --extended-regexp '[^.!?]*\?' || true)

if [ "${#violations[@]}" -eq 0 ]; then
    exit 0
fi

reason=$'Your last message has question(s) offering alternatives without bracket-prefix accept tokens (per ~/.claude/CLAUDE.md Output > inline binary/ternary asks):\n\n'
for v in "${violations[@]}"; do
    reason+="- ${v}"$'\n'
done
reason+=$'\n🤖 [for Claude] Rewrite each alternative as [x]remainder (case-insensitive accept letter, wrapped in bold inline code), then re-send. See the pre-send checklist in CLAUDE.md.'

command jq --null-input --compact-output \
    --arg reason "${reason}" \
    '{decision: "block", reason: $reason}'
