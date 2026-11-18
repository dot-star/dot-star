#!/usr/bin/env bash
# Tests for link_session_dir_into_worktree.sh.
# Builds a throwaway repository with a worktree, feeds the hook a synthetic
# EnterWorktree payload, and asserts the link, the exclude entry, a clean
# `git status` and a worktree that `git worktree remove` still takes down.
#
# Run: bash ai/files/Users/user/.claude/hooks/link_session_dir_into_worktree_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/link_session_dir_into_worktree.sh"

if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

source "${SCRIPT_DIR}/claude_session_dir.inc.sh"

scratch=$(mktemp -d)
session_dirs=()
cleanup() {
    rm -rf "${scratch}"
    for session_dir in "${session_dirs[@]}"; do
        rm -rf "${session_dir}"
    done
}
trap cleanup EXIT

export GIT_AUTHOR_NAME=test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test
export GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null

passes=0
fails=0

# Record one assertion's outcome.
check() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "${actual}" == "${expected}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %s\n" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expected}" "${actual}" "${label}"
    fi
}

# Run the hook on an EnterWorktree payload for the given session and worktree.
run_hook() {
    local session_id="$1"
    local worktree="$2"

    command jq \
        --null-input \
        --compact-output \
        --arg session_id "${session_id}" \
        --arg worktree "${worktree}" \
        '{session_id: $session_id, tool_name: "EnterWorktree", tool_response: {worktreePath: $worktree}}' |
        "${HOOK}"
}

repo="${scratch}/repo"
git init \
    --initial-branch="master" \
    --quiet \
    "${repo}"
git -C "${repo}" commit \
    --allow-empty \
    --message "base" \
    --quiet
worktree="${repo}/.claude/worktrees/feature"
git -C "${repo}" worktree add \
    --quiet \
    -b "worktree-feature" \
    "${worktree}"

first_session="12345678-90ab-cdef-1234-567890abcdef"
second_session="23456789-0abc-def1-2345-67890abcdef1"
first_dir=$(claude_session_dir "${first_session}")
second_dir=$(claude_session_dir "${second_session}")
session_dirs+=("${first_dir}" "${second_dir}")

run_hook "${first_session}" "${worktree}"
check "link points at the session dir" "${first_dir}" "$(readlink "${worktree}/.scratch")"
check "session dir exists" "yes" "$([[ -d "${first_dir}" ]] && echo yes || echo no)"
check "worktree status stays clean" "" "$(git -C "${worktree}" status --porcelain)"

run_hook "${second_session}" "${worktree}"
check "switch repoints link at new session" "${second_dir}" "$(readlink "${worktree}/.scratch")"
exclude_file="${repo}/.git/info/exclude"
check "exclude entry written once" "1" "$(grep --count --fixed-strings --line-regexp "/.scratch" "${exclude_file}")"

run_hook "" "${worktree}"
check "missing session id: no-op" "${second_dir}" "$(readlink "${worktree}/.scratch")"

run_hook "${first_session}" ""
check "missing worktree path: no-op" "0" "$?"

check "worktree remove succeeds" "0" "$(
    git -C "${repo}" worktree remove "${worktree}" 2>/dev/null
    echo $?
)"
check "remove leaves session dir intact" "yes" "$([[ -d "${second_dir}" ]] && echo yes || echo no)"

echo
echo "${passes} passed, ${fails} failed"
if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
