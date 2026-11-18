#!/usr/bin/env bash
#
# Hook for EnterWorktree (PostToolUse): link the session-scoped tmp dir into the
# worktree as `.scratch`, so a terminal sitting in the worktree can `cd .scratch`
# to reach the session's temporary files (and, through it, the harness
# scratchpad that create_session_tmp_dir.sh links inside).
#
# Fires on a switch into an existing worktree too, repointing a link a past
# session left behind at this session's dir.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

link_name=".scratch"

{
    IFS= read -r -d '' session_id
    IFS= read -r -d '' worktree
} < <(
    command jq \
        --raw-output0 \
        '.session_id // "", .tool_response.worktreePath // ""'
)

dir=$(claude_session_dir "${session_id}")
if [ -z "${dir}" ]; then
    exit 0
fi

if [ -z "${worktree}" ] || [ ! -d "${worktree}" ]; then
    exit 0
fi

mkdir -p "${dir}"
ln -sfn "${dir}" "${worktree}/${link_name}"

# Hide the link from `git status`, so clean-tree checks (land, promote) still
# pass. Git has no per-worktree exclude: this file is shared by every worktree.
cd "${worktree}"
exclude_file=$(
    git rev-parse \
        --path-format="absolute" \
        --git-path "info/exclude"
)
mkdir -p "$(dirname -- "${exclude_file}")"
if ! grep \
    --fixed-strings \
    --line-regexp \
    --quiet \
    "/${link_name}" \
    "${exclude_file}" 2>/dev/null; then
    printf '/%s\n' "${link_name}" >>"${exclude_file}"
fi
