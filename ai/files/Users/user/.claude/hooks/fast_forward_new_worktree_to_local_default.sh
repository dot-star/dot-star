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

data=$(cat)

# Act only on a new worktree ("Created worktree at <path> on branch ..."),
# never on a switch into an existing one, which may hold work.
response=$(printf '%s' "${data}" |
    command jq --raw-output '.tool_response | tostring')
worktree=$(printf '%s' "${response}" |
    sed -n 's/.*Created worktree at \([^ ]*\) on branch.*/\1/p' |
    head -n 1)
if [ -z "${worktree}" ] || [ ! -d "${worktree}" ]; then
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
