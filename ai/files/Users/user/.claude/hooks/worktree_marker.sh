#!/usr/bin/env bash
#
# PostToolUse hook for EnterWorktree / ExitWorktree: maintain a session-scoped
# marker file recording the worktree the session is currently working in.
# statusline.sh reads this file to render "[worktree: <name>]".

set -euo pipefail

data=$(cat)

sid=$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')
sid="${sid//[^a-zA-Z0-9-]/}"
if [ -z "${sid}" ]; then
    exit 0
fi

dir="/tmp/claude/${sid}"
marker="${dir}/worktree"

tool=$(printf '%s' "${data}" | command jq --raw-output '.tool_name // empty')
case "${tool}" in
EnterWorktree)
    # Extract the new worktree path from the tool response text
    # ("Created worktree at <path> on branch ..." or "Switched ...").
    response=$(printf '%s' "${data}" | command jq --raw-output '.tool_response | tostring')
    path=$(printf '%s' "${response}" | grep --only-matching --extended-regexp '/[A-Za-z0-9_./-]+/worktrees/[A-Za-z0-9_.-]+' | head -n 1)
    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${marker}"
    fi
    ;;
ExitWorktree)
    if [ -f "${marker}" ]; then
        rm "${marker}"
    fi
    ;;
esac
