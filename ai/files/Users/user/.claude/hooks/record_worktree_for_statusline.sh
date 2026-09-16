#!/usr/bin/env bash
#
# Hook for EnterWorktree / ExitWorktree (PostToolUse): maintain a
# session-scoped marker file recording the worktree the session is currently
# working in. render_statusline.sh reads this file to render
# "[<worktree-name>]", and falls back to inspecting the cwd when there is none
# (a worktree the session was launched inside, or a resumed session).

set -euo pipefail

data=$(cat)

sid=$(printf '%s' "${data}" |
    command jq --raw-output '.session_id // empty')
sid="${sid//[^a-zA-Z0-9-]/}"
if [ -z "${sid}" ]; then
    exit 0
fi

dir="/tmp/claude/${sid}"
marker="${dir}/worktree"

tool=$(printf '%s' "${data}" |
    command jq --raw-output '.tool_name // empty')
case "${tool}" in
EnterWorktree)
    # Extract the new worktree path from the tool response text
    # ("Created worktree at <path> on branch ..." or "Switched ...").
    response=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_response | tostring')
    path=$(printf '%s' "${response}" |
        grep --only-matching --extended-regexp '/[A-Za-z0-9_./-]+/worktrees/[A-Za-z0-9_.-]+' |
        head -n 1)
    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${marker}"
    fi
    ;;
ExitWorktree)
    # Drop the marker; we're no longer in a worktree.
    if [ -f "${marker}" ]; then
        rm "${marker}"
    fi
    ;;
esac
