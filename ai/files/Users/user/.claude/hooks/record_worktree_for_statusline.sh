#!/usr/bin/env bash
#
# Hook for EnterWorktree / ExitWorktree / Write / Edit / Bash (PostToolUse):
# maintain a session-scoped marker file recording the worktree the session is
# currently working in. render_statusline.sh reads this file to render
# "[<worktree-name>]", and falls back to inspecting the cwd when there is none
# (a worktree the session was launched inside, or a resumed session).
#
# Write / Edit record the worktree an edited file sits in and Bash records the
# path a `git worktree add` creates, so a worktree made without EnterWorktree
# (in another repo, by hand) still shows. render_statusline.sh skips a marker
# whose directory is gone, so a teardown needs no hook of its own.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

data=$(cat)

dir=$(claude_session_dir "$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')")
if [ -z "${dir}" ]; then
    exit 0
fi

marker="${dir}/worktree"

# Print the first "<...>/worktrees/<name>" path in $1, or nothing.
worktree_path_in() {
    printf '%s' "$1" |
        grep --only-matching --extended-regexp '/[A-Za-z0-9_./-]+/worktrees/[A-Za-z0-9_.-]+' |
        head -n 1 ||
        true
}

# Record $1 as the session's worktree, skipping a path that doesn't exist.
record_worktree() {
    local path="$1"

    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${marker}"
    fi
}

tool=$(printf '%s' "${data}" |
    command jq --raw-output '.tool_name // empty')
case "${tool}" in
Bash)
    # Read the path after "worktree add", skipping any "git -C <path>" before it.
    command=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_input.command // empty')
    case "${command}" in
    *"worktree add"*)
        record_worktree "$(worktree_path_in "${command#*worktree add}")"
        ;;
    esac
    ;;
Edit | Write)
    file_path=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_input.file_path // empty')
    record_worktree "$(worktree_path_in "${file_path}")"
    ;;
EnterWorktree)
    # Extract the new worktree path from the tool response text
    # ("Created worktree at <path> on branch ..." or "Switched ...").
    response=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_response | tostring')
    record_worktree "$(worktree_path_in "${response}")"
    ;;
ExitWorktree)
    # Drop the marker; we're no longer in a worktree.
    if [ -f "${marker}" ]; then
        rm "${marker}"
    fi
    ;;
esac
