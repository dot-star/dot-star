#!/usr/bin/env bash

# Check that the hook records the main checkout of the repo each git commit
# lands in, and records nothing for other commands or outside claude_run.
#
# Run: bash ai/files/Users/user/.claude/hooks/record_committed_repo_for_claude_run_test.sh

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/record_committed_repo_for_claude_run.sh"

# Build two throwaway repos, one with a linked worktree.
SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
for repo in first second; do
    git init --quiet "${SANDBOX}/${repo}"
    git -C "${SANDBOX}/${repo}" commit \
        --allow-empty \
        --quiet \
        --message "initial"
done
git -C "${SANDBOX}/first" worktree add --quiet "${SANDBOX}/first_worktree"

export CLAUDE_RUN_COMMITTED_REPOS="${SANDBOX}/committed_repos"

failures=0

assert_recorded() {
    # Feed the hook <command> run from <cwd> and compare the recorded repos
    # against <expected>.
    local label="$1"
    local cwd="$2"
    local cmd="$3"
    local expected="$4"

    rm --force -- "${CLAUDE_RUN_COMMITTED_REPOS}"
    jq --null-input --compact-output \
        --arg cmd "${cmd}" \
        --arg cwd "${cwd}" \
        '{cwd: $cwd, tool_input: {command: $cmd}}' |
        bash "${HOOK}"

    local actual=""
    if [[ -f "${CLAUDE_RUN_COMMITTED_REPOS}" ]]; then
        actual="$(cat -- "${CLAUDE_RUN_COMMITTED_REPOS}")"
    fi

    if [[ "${actual}" == "${expected}" ]]; then
        echo "✓ ${label}"
    else
        echo "✗ ${label}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        failures=$((failures + 1))
    fi
}

assert_recorded "commit in cwd records cwd's repo" \
    "${SANDBOX}/first" 'git commit --message "foo"' "${SANDBOX}/first"
assert_recorded "commit in a worktree records its main checkout" \
    "${SANDBOX}/first_worktree" 'git commit --message "foo"' "${SANDBOX}/first"
assert_recorded "git -C <dir> records that dir's repo" \
    "${SANDBOX}/first" "git -C ${SANDBOX}/second commit --message foo" "${SANDBOX}/second"
assert_recorded "git -C \"<dir>\" records that dir's repo" \
    "${SANDBOX}/first" "git -C \"${SANDBOX}/second\" commit --message foo" "${SANDBOX}/second"
assert_recorded "relative git -C <dir> resolves against cwd" \
    "${SANDBOX}/first" 'git -C ../second commit --message foo' "${SANDBOX}/second"
assert_recorded "non-commit git command records nothing" \
    "${SANDBOX}/first" 'git status' ""
assert_recorded "commit outside a repo records nothing" \
    "${SANDBOX}" 'git commit --message foo' ""

unset CLAUDE_RUN_COMMITTED_REPOS
if jq --null-input --compact-output \
    --arg cwd "${SANDBOX}/first" \
    '{cwd: $cwd, tool_input: {command: "git commit"}}' |
    bash "${HOOK}"; then
    echo "✓ outside claude_run exits cleanly"
else
    echo "✗ outside claude_run exits cleanly"
    failures=$((failures + 1))
fi

git -C "${SANDBOX}/first" worktree remove --force "${SANDBOX}/first_worktree"
rm -r -- "${SANDBOX}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
