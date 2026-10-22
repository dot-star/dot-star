#!/usr/bin/env bash
#
# Hook for EnterWorktree / ExitWorktree / Write / Edit / Bash (PostToolUse):
# maintain a session-scoped marker file recording the worktree the session is
# currently working in. render_statusline.sh reads this file to render
# "[<worktree-name>]", and falls back to inspecting the cwd when there is none
# (a worktree the session was launched inside, or a resumed session).
#
# Write / Edit record the worktree an edited file sits in and Bash records the
# path a `git worktree add` creates, else any existing worktree the command
# names (a later `git -C <worktree>` catches an add whose path hid behind a
# shell variable), so a worktree made without EnterWorktree
# (in another repo, by hand) still shows. render_statusline.sh skips a marker
# whose directory is gone, so a teardown needs no hook of its own.
#
# A second marker, last_repo, records the repo the session last worked in,
# worktree or not (Write / Edit add the repo an edited file sits in), so
# report_cwd_for_new_tabs.py can open a new tab where the work happened.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

data=$(cat)

dir=$(claude_session_dir "$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')")
if [ -z "${dir}" ]; then
    exit 0
fi

marker="${dir}/worktree"
last_repo_marker="${dir}/last_repo"

# Print the first existing "<...>/worktrees/<name>" path in $1, or nothing.
# Skip a missing one: an unexpanded "$R/worktrees/foo" matches as "/worktrees/foo".
worktree_path_in() {
    local path

    while IFS= read -r path; do
        if [ -d "${path}" ]; then
            printf '%s' "${path}"
            return 0
        fi
    done < <(printf '%s' "$1" |
        grep --only-matching --extended-regexp '/[A-Za-z0-9_./-]+/worktrees/[A-Za-z0-9_.-]+' ||
        true)
}

# Record $1 as the session's worktree, skipping a path that doesn't exist.
record_worktree() {
    local path="$1"

    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${marker}"
    fi
}

# Record $1 as the repo the session last worked in, skipping an empty path.
record_last_repo() {
    local path="$1"

    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${last_repo_marker}"
    fi
}

# Print the top of the git checkout holding file $1, or nothing outside one.
repo_root_of() {
    git -C "$(dirname -- "$1")" rev-parse --show-toplevel 2>/dev/null ||
        true
}

tool=$(printf '%s' "${data}" |
    command jq --raw-output '.tool_name // empty')
case "${tool}" in
Bash)
    command=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_input.command // empty')
    path=""

    # Prefer the path after "worktree add", skipping any "git -C <path>" before it.
    case "${command}" in
    *"worktree add"*)
        path=$(worktree_path_in "${command#*worktree add}")
        ;;
    esac

    # Fall back to any worktree the command works in, as Edit / Write do.
    if [ -z "${path}" ]; then
        path=$(worktree_path_in "${command}")
    fi

    record_worktree "${path}"
    record_last_repo "${path}"
    ;;
Edit | Write)
    file_path=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_input.file_path // empty')
    record_worktree "$(worktree_path_in "${file_path}")"
    record_last_repo "$(repo_root_of "${file_path}")"
    ;;
EnterWorktree)
    # Extract the new worktree path from the tool response text
    # ("Created worktree at <path> on branch ..." or "Switched ...").
    response=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_response | tostring')
    path=$(worktree_path_in "${response}")
    record_worktree "${path}"
    record_last_repo "${path}"
    ;;
ExitWorktree)
    # Drop the markers; we're no longer in a worktree.
    if [ -f "${marker}" ]; then
        rm "${marker}"
    fi

    if [ -f "${last_repo_marker}" ]; then
        rm "${last_repo_marker}"
    fi
    ;;
esac
