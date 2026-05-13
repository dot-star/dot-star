#!/usr/bin/env bash
#
# statusLine hook: when the current Claude session is associated with a git
# worktree, print a "[worktree: <name>]" marker. Prints nothing otherwise.
#
# Sources, in order:
#   1. Session-scoped marker written by worktree_marker.sh on EnterWorktree;
#      survives cd'ing back to main while the worktree is still in use.
#   2. The cwd itself, for worktrees created outside this session (manual
#      `git worktree add`, an existing worktree entered via `path:`, etc.).

set -euo pipefail

data=$(cat)

sid=$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')
sid="${sid//[^a-zA-Z0-9-]/}"
marker="/tmp/claude/${sid}/worktree"
if [ -n "${sid}" ] && [ -f "${marker}" ]; then
    path=$(head -n 1 "${marker}")
    if [ -d "${path}" ]; then
        name="${path##*/}"
        printf '[worktree: %s]\n' "${name}"
        exit 0
    fi
fi

cwd=$(printf '%s' "${data}" | command jq --raw-output '.cwd // .workspace.current_dir // empty')
if [ -z "${cwd}" ]; then
    exit 0
fi

cd "${cwd}"

gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null || true)
case "${gitdir}" in
*/worktrees/*)
    name="${gitdir##*/worktrees/}"
    name="${name%%/*}"
    printf '[worktree: %s]\n' "${name}"
    ;;
esac
