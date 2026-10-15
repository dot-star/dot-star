#!/usr/bin/env bash
#
# PostToolUse hook (Bash): append the main checkout of the repo a git commit
# lands in to the file claude_run exports, so claude_run can check every repo
# the session committed to for unpushed commits on exit.

set -euo pipefail

if [[ -z "${CLAUDE_RUN_COMMITTED_REPOS:-}" ]]; then
    exit 0
fi

input="$(cat)"
cmd="$(jq --raw-output '.tool_input.command // empty' <<<"${input}")"
cwd="$(jq --raw-output '.cwd // empty' <<<"${input}")"

# Pass over anything but a git command mentioning commit. A loose match only
# costs one extra repo checked on exit.
case "${cmd}" in
*git*commit*) ;;
*) exit 0 ;;
esac

# Target the dir a `git -C <dir>` names, else the session's cwd.
target_dir="${cwd}"
if [[ "${cmd}" =~ git\ -C\ \"([^\"]+)\" ]]; then
    target_dir="${BASH_REMATCH[1]}"
elif [[ "${cmd}" =~ git\ -C\ ([^ ]+) ]]; then
    target_dir="${BASH_REMATCH[1]}"
fi

# Expand a leading `~` and resolve a relative dir against the session's cwd.
if [[ "${target_dir}" == "~"* ]]; then
    target_dir="${HOME}${target_dir:1}"
elif [[ "${target_dir}" != /* ]]; then
    target_dir="${cwd}/${target_dir}"
fi

# Record the main checkout, since a worktree the session lands is gone by exit.
git_common_dir="$(
    git -C "${target_dir}" rev-parse \
        --path-format=absolute \
        --git-common-dir \
        2>/dev/null
)" ||
    exit 0
dirname "${git_common_dir}" >>"${CLAUDE_RUN_COMMITTED_REPOS}"
