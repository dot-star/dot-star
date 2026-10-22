#!/usr/bin/env bash

# Check that the hook records the worktree a Bash command creates or works in,
# skipping paths that don't exist (an unexpanded "$R/..." among them).
#
# Run: bash ai/files/Users/user/.claude/hooks/record_worktree_for_statusline_test.sh

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/record_worktree_for_statusline.sh"

# Build a throwaway repo with two linked worktrees.
SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
git init --quiet "${SANDBOX}/repo"
git -C "${SANDBOX}/repo" commit \
    --allow-empty \
    --quiet \
    --message "initial"
for name in first second; do
    git -C "${SANDBOX}/repo" worktree add \
        --quiet \
        -b "${name}" \
        "${SANDBOX}/repo/worktrees/${name}"
done

SESSION_ID="test-record-worktree-$$"
MARKER="/tmp/claude/${SESSION_ID:0:7}/worktree"

failures=0

assert_recorded() {
    # Feed the hook a Bash <command> and compare the marker against <expected>.
    local label="$1"
    local cmd="$2"
    local expected="$3"

    rm --force -- "${MARKER}"
    jq --null-input --compact-output \
        --arg cmd "${cmd}" \
        --arg sid "${SESSION_ID}" \
        '{session_id: $sid, tool_name: "Bash", tool_input: {command: $cmd}}' |
        bash "${HOOK}"

    local actual=""
    if [[ -f "${MARKER}" ]]; then
        actual="$(cat -- "${MARKER}")"
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

assert_recorded "worktree add records the new worktree" \
    "git worktree add ${SANDBOX}/repo/worktrees/first" "${SANDBOX}/repo/worktrees/first"
assert_recorded "worktree add skips the git -C path before it" \
    "git -C ${SANDBOX}/repo/worktrees/second worktree add ${SANDBOX}/repo/worktrees/first" "${SANDBOX}/repo/worktrees/first"
assert_recorded "command working in a worktree records it" \
    "W=${SANDBOX}/repo/worktrees/second; git -C \$W status" "${SANDBOX}/repo/worktrees/second"
assert_recorded "unexpanded variable path is skipped for a real one" \
    "R=${SANDBOX}/repo; ls \$R/worktrees/first ${SANDBOX}/repo/worktrees/second" "${SANDBOX}/repo/worktrees/second"
assert_recorded "missing worktree path records nothing" \
    "ls ${SANDBOX}/repo/worktrees/gone" ""
assert_recorded "command naming no worktree records nothing" \
    "git status" ""

rm -r -- "/tmp/claude/${SESSION_ID:0:7}" "${SANDBOX}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
