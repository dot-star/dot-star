#!/usr/bin/env bash
#
# SessionStart hook: prune entries from the project's
# .claude/settings.local.json that are already covered by ~/.claude/settings.json
# (deleting the file if it ends up empty), then surface a system reminder
# pointing Claude at the triage-permissions skill if entries remain that
# need judgment.

set -euo pipefail

cwd=$(command jq --raw-output '.cwd // empty')
if [ -z "${cwd}" ]; then
    exit 0
fi

local_file="${cwd}/.claude/settings.local.json"
if [ ! -f "${local_file}" ]; then
    exit 0
fi

global_file="${HOME}/.claude/settings.json"
prune_against_global='
    ($global[0].permissions.allow // []) as $ga |
    ($global[0].permissions.deny // []) as $gd |
    .permissions.allow = ((.permissions.allow // []) - $ga) |
    .permissions.deny = ((.permissions.deny // []) - $gd) |
    if ((.permissions.allow // []) | length) == 0 then del(.permissions.allow) else . end |
    if ((.permissions.deny // []) | length) == 0 then del(.permissions.deny) else . end |
    if ((.permissions // {}) | length) == 0 then del(.permissions) else . end
'

if [ -f "${global_file}" ]; then
    pruned=$(command jq --slurpfile global "${global_file}" "${prune_against_global}" "${local_file}")
else
    pruned=$(command jq '.' "${local_file}")
fi

remaining=$(printf '%s' "${pruned}" |
    command jq '(.permissions.allow // []) + (.permissions.deny // []) | length')

if [ "${remaining:-0}" -le 0 ]; then
    rm "${local_file}"
    exit 0
fi

current=$(command jq '.' "${local_file}")
if [ "${current}" != "${pruned}" ]; then
    printf '%s\n' "${pruned}" >"${local_file}"
fi

message="Project .claude/settings.local.json has ${remaining} permission entries. Invoke the triage-permissions skill to triage and promote shareable rules to dot-star."

command jq --null-input --compact-output \
    --arg message "${message}" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $message}}'
