#!/usr/bin/env bash
#
# UserPromptSubmit hook: inject the current wall-clock time on every prompt, and
# shout when the calendar day has rolled over since the session began. The
# harness stamps `currentDate` once at session start and never refreshes it, so
# a session resumed days later reasons off a stale date while still sounding
# certain. Stay quiet on the ordinary case so the misleading one stands out.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

input=$(cat)
session_dir=$(claude_session_dir "$(command jq --raw-output '.session_id // empty' <<<"${input}")")

now=$(date)
today=$(date +%Y-%m-%d)

context="Current time: ${now}"

# Compare today against the day stamped on this session's first prompt. The
# stamp lives in the session tmp dir, which survives a resume under the same
# session id, so a Friday session picked up on Sunday still carries Friday's
# mark. Test for a non-empty file so a half-written stamp gets rewritten rather
# than read as a rollover.
if [ -n "${session_dir}" ]; then
    stamp="${session_dir}/session-start-date"
    if [ -s "${stamp}" ]; then
        started=$(cat "${stamp}")
        if [ "${started}" != "${today}" ]; then
            context=$'⚠️ DATE ROLLED OVER since this session began.'
            context+=$'\n'"Session started ${started}, it is now ${now}."
            context+=$'\nRe-check anything resting on "today", "tonight", or elapsed time.'
        fi
    else
        mkdir -p "${session_dir}"
        printf '%s\n' "${today}" >"${stamp}"
    fi
fi

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $context}}'
