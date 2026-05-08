#!/usr/bin/env bash
#
# SessionStart hook: if the project's .claude/settings.local.json has any
# permission entries, surface a system reminder pointing Claude at the
# triage-permissions skill so the buildup gets cleaned up unprompted.

set -euo pipefail

cwd=$(command jq --raw-output '.cwd // empty')
if [ -z "${cwd}" ]; then
    exit 0
fi

local_file="${cwd}/.claude/settings.local.json"
if [ ! -f "${local_file}" ]; then
    exit 0
fi

count=$(command jq '(.permissions.allow // []) | length' "${local_file}" 2>/dev/null || echo 0)
if [ "${count:-0}" -le 0 ]; then
    exit 0
fi

message="Project .claude/settings.local.json has ${count} permission entries. Invoke the triage-permissions skill to triage and promote shareable rules to dot-star."

command jq --null-input --compact-output \
    --arg message "${message}" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $message}}'
