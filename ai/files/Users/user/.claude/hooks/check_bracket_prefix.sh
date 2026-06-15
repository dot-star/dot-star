#!/usr/bin/env bash
#
# Stop hook: enforce the bracket-prefix rule for inline-prose alternative
# questions (per ~/.claude/CLAUDE.md, Output > inline binary/ternary asks).
# Block when the last assistant message contains a ?-terminated sentence
# that offers alternatives (` or `) but lacks any `[x]remainder` accept-prefix
# token, and feed the violations back so Claude rewrites the question.

set -euo pipefail

input=$(cat)

# Skip re-blocking once Claude is already re-running after a Stop block.
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
prose=$(printf '%s\n' "${msg}" |
    sed -E '/^```/,/^```/d')

bracket_re='\[[a-zA-Z]{1,3}\][a-zA-Z]'

violations=()

# Flag uncovered alternative questions in one blank-line-delimited paragraph.
# A compliant block layout puts the stem on its own line and the bracketed
# options beneath it (per CLAUDE.md), so a `[x]remainder` token anywhere in the
# paragraph clears every line in it; judge brackets per paragraph, not per line.
check_paragraph() {
    local para="$1"
    if printf '%s' "${para}" | grep --quiet --extended-regexp "${bracket_re}"; then
        return
    fi

    local line
    local stripped
    local trimmed

    while IFS= read -r line; do
        # Strip inline-code spans so a quoted example like `... or ...?` reads as
        # plain prose with no live question.
        stripped=$(printf '%s' "${line}" | sed -E 's/`[^`]*`//g')
        if ! printf '%s' "${stripped}" | grep --quiet --fixed-strings ' or '; then
            continue
        fi
        if ! printf '%s' "${stripped}" | grep --quiet --fixed-strings '?'; then
            continue
        fi
        trimmed=$(printf '%s' "${line}" |
            sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        if [ -n "${trimmed}" ]; then
            violations+=("${trimmed}")
        fi
    done <<<"${para}"
}

# Accumulate lines into paragraphs, flushing each at a blank line.
para=""
while IFS= read -r line || [ -n "${line}" ]; do
    if [ -z "${line}" ]; then
        if [ -n "${para}" ]; then
            check_paragraph "${para}"
            para=""
        fi
        continue
    fi
    if [ -z "${para}" ]; then
        para="${line}"
    else
        para+=$'\n'"${line}"
    fi
done <<<"${prose}"
if [ -n "${para}" ]; then
    check_paragraph "${para}"
fi

if [ "${#violations[@]}" -eq 0 ]; then
    exit 0
fi

reason=$'Your last message has question(s) offering alternatives without bracket-prefix accept tokens (per ~/.claude/CLAUDE.md Output > inline binary/ternary asks):\n\n'
for v in "${violations[@]}"; do
    reason+="- ${v}"$'\n'
done
reason+=$'\n┌─ 🤖 for Claude ──────────────────────────────────────'
reason+=$'\n│ Rewrite each alternative as [x]remainder (case-insensitive'
reason+=$'\n│ accept letter, wrapped in bold inline code), then re-send.'
reason+=$'\n│ See the pre-send checklist in CLAUDE.md.'
reason+=$'\n└──────────────────────────────────────────────────────'

command jq --null-input --compact-output \
    --arg reason "${reason}" \
    '{decision: "block", reason: $reason}'
