#!/usr/bin/env bash
#
# Stop hook: enforce the bracket-prefix rule for inline-prose alternative
# questions (per ~/.claude/CLAUDE.md, Output > inline binary/ternary asks).
# Block when the last assistant message contains a ?-terminated sentence
# that offers alternatives (` or `) or pitches a commit/land/promote/push
# follow-up but lacks any `[x]remainder` accept-prefix token, and feed the
# violations back so Claude rewrites the question. Block too when an option
# is bracketed but malformed: the remainder placed outside the inline-code
# span renders the `**` literally instead of bolding the option.

set -euo pipefail

input=$(cat)

msg=$(printf '%s' "${input}" |
    command jq --raw-output '.last_assistant_message // empty')
if [ -z "${msg}" ]; then
    exit 0
fi

# Strip fenced code blocks so `or` and quoted bad examples don't trigger.
prose=$(printf '%s\n' "${msg}" |
    sed -E '/^```/,/^```/d')

# Emit the Stop-hook payload that hands the feedback back to Claude.
block() {
    local reason="$1"
    command jq --null-input --compact-output \
        --arg reason "${reason}" \
        '{decision: "block", reason: $reason}'
}

# Catch a bracket option whose remainder sits outside the code span, rendering
# a literal `**`. Check ahead of the stop_hook_active guard below: the slip
# lands on re-sends, exactly the messages that guard waves through.
broken_span_re='`\[[a-zA-Z0-9-]{1,4}\]`\*\*[a-zA-Z0-9-]'
broken_spans=$(printf '%s\n' "${prose}" |
    grep --extended-regexp "${broken_span_re}" |
    sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//') || true

if [ -n "${broken_spans}" ]; then
    reason=$'Your last message has bracket option(s) whose remainder sits outside the inline-code span, so the `**` renders literally (per ~/.claude/CLAUDE.md Output > bracket-prefix choice asks):\n\n'
    while IFS= read -r broken; do
        reason+="- ${broken}"$'\n'
    done <<<"${broken_spans}"
    reason+=$'\n┌─ 🤖 for Claude ───────────────────────────────────────────────────────'
    reason+=$'\n│ Move the remainder inside the span, one span per option. Send the fix'
    reason+=$'\n│ only, not the whole message.'
    reason+=$'\n│   Wrong: **`[d]`**rier tone'
    reason+=$'\n│   Right: **`[d]rier tone`**'
    reason+=$'\n└───────────────────────────────────────────────────────────────────────'

    block "${reason}"
    exit 0
fi

# Skip re-blocking once Claude is already re-running after a Stop block.
stop_hook_active=$(printf '%s' "${input}" |
    command jq --raw-output '.stop_hook_active // false')
if [ "${stop_hook_active}" = "true" ]; then
    exit 0
fi

bracket_re='\[[a-zA-Z]{1,3}\][a-zA-Z]'

# Match a follow-up offer to commit/land/promote/push; these need bracket
# options even when phrased as a bare yes/no question with no ` or `.
offer_re='want me to|should i|shall i'
action_re='commit|land|promote|push'

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
    local is_alternative
    local is_offer

    while IFS= read -r line; do
        # Strip inline-code spans so a quoted example like `... or ...?` reads as
        # plain prose with no live question.
        stripped=$(printf '%s' "${line}" | sed -E 's/`[^`]*`//g')

        # Require a live question; every judgment below targets a `?`-bearing line.
        if ! printf '%s' "${stripped}" | grep --quiet --fixed-strings '?'; then
            continue
        fi

        is_alternative=false
        if printf '%s' "${stripped}" | grep --quiet --fixed-strings ' or '; then
            is_alternative=true
        fi

        # Pair an offer lead (want me to / should i) with a staging verb so a
        # status question like "Did the commit land?" stays clear of the net.
        is_offer=false
        if printf '%s' "${stripped}" | grep --quiet --ignore-case --extended-regexp "${offer_re}" &&
            printf '%s' "${stripped}" | grep --quiet --ignore-case --extended-regexp "${action_re}"; then
            is_offer=true
        fi

        if [ "${is_alternative}" = false ] && [ "${is_offer}" = false ]; then
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
reason+=$'\n┌─ 🤖 for Claude ───────────────────────────────────────────────────────'
reason+=$'\n│ Rewrite each alternative as [x]remainder (bracketed accept letter).'
reason+=$'\n│ See CLAUDE.md checklist. Send the fix only, not the whole message.'
reason+=$'\n└───────────────────────────────────────────────────────────────────────'

block "${reason}"
