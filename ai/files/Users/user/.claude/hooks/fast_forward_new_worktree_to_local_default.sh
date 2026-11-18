#!/usr/bin/env bash
#
# Hook for EnterWorktree (PostToolUse): fast-forward a newly created worktree
# from origin/<default> to the local default branch when the local branch
# already contains it.
#
# `worktree.baseRef: "fresh"` branches new worktrees from origin/<default>,
# which moves only on push. Lands and promotes fast-forward the local default
# branch without pushing, so between pushes every new worktree would start
# behind and need a rebase. A local branch missing commits from origin (pushed
# from another machine) leaves the worktree on origin/<default>, as before.

set -euo pipefail

{
    IFS= read -r -d '' switch_path
    IFS= read -r -d '' worktree
} < <(
    command jq \
        --raw-output0 \
        '.tool_input.path // "", .tool_response.worktreePath? // ""'
)

# Act only on a new worktree, never on a switch into an existing one (input
# `path`), which may hold work.
if [ -n "${switch_path}" ]; then
    exit 0
elif [ -z "${worktree}" ]; then
    exit 0
elif [ ! -d "${worktree}" ]; then
    exit 0
fi

cd "${worktree}"

remote_default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
if [ -z "${remote_default}" ]; then
    exit 0
fi

local_default="${remote_default#origin/}"
if ! git show-ref \
    --quiet \
    --verify \
    "refs/heads/${local_default}"; then
    exit 0
fi

head_commit=$(git rev-parse HEAD)
remote_commit=$(git rev-parse "${remote_default}")
local_commit=$(git rev-parse "${local_default}")

# Leave a worktree that didn't start at origin/<default> (a `head` base, or a
# hook that already moved it), and one with nothing to gain.
if [ "${head_commit}" != "${remote_commit}" ] || [ "${local_commit}" = "${remote_commit}" ]; then
    exit 0
fi

if ! git merge-base --is-ancestor "${remote_commit}" "${local_commit}"; then
    exit 0
fi

ahead=$(git rev-list --count "${remote_commit}..${local_commit}")
if ! git merge \
    --ff-only \
    --quiet \
    "${local_default}" >&2; then
    exit 0
fi

context="Fast-forwarded the new worktree from ${remote_default} to local ${local_default}"
context+=" (${ahead} unpushed commits), so it starts from the latest landed work."
command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
