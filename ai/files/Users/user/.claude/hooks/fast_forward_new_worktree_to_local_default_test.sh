#!/usr/bin/env bash
# Tests for fast_forward_new_worktree_to_local_default.sh.
# Builds a throwaway repository with a remote, creates a worktree at
# origin/master the way `worktree.baseRef: "fresh"` does, feeds the hook a
# synthetic EnterWorktree payload, and asserts where the worktree's HEAD ends up.
#
# Run: bash ai/files/Users/user/.claude/hooks/fast_forward_new_worktree_to_local_default_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/fast_forward_new_worktree_to_local_default.sh"

if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf "${scratch}"' EXIT

export GIT_AUTHOR_NAME=test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test
export GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null

passes=0
fails=0
case_number=0

# Add an empty commit with the given message to the checkout at $1.
commit_empty() {
    local checkout="$1"
    local message="$2"

    git -C "${checkout}" commit \
        --allow-empty \
        --message "${message}" \
        --quiet
}

# Push master from the checkout at $1.
push_master() {
    local checkout="$1"

    git -C "${checkout}" push \
        --quiet \
        origin \
        master
}

# Clone the bare remote under $1 into $2.
clone_remote() {
    local dir="$1"
    local checkout="$2"

    git clone \
        --quiet \
        "${dir}/remote.git" \
        "${checkout}" 2>/dev/null
}

# Create a repository whose master tracks a bare remote, both at one commit.
make_repo() {
    local dir="$1"

    git init \
        --bare \
        --initial-branch=master \
        --quiet \
        "${dir}/remote.git"
    clone_remote "${dir}" "${dir}/repo"
    commit_empty "${dir}/repo" base
    push_master "${dir}/repo"
    git -C "${dir}/repo" remote set-head origin master >/dev/null
}

# Add a worktree branched from origin/master and print its path.
add_worktree() {
    local dir="$1"
    local name="$2"
    local worktree="${dir}/repo/.claude/worktrees/${name}"

    git -C "${dir}/repo" worktree add \
        --quiet \
        -b "worktree-${name}" \
        "${worktree}" \
        origin/master
    printf '%s\n' "${worktree}"
}

# Run the hook on an EnterWorktree response and print its stdout.
run_hook() {
    local response="$1"

    command jq \
        --null-input \
        --compact-output \
        --arg response "${response}" \
        '{tool_name: "EnterWorktree", tool_response: $response}' |
        "${HOOK}" 2>/dev/null
}

# Assert the worktree's HEAD and whether the hook spoke.
check() {
    local label="$1"
    local worktree="$2"
    local expected_head="$3"
    local out="$4"
    local expect_output="$5"
    local actual_head
    local actual_output

    actual_head=$(git -C "${worktree}" rev-parse HEAD)
    if [[ -n "${out}" ]]; then
        actual_output=fires
    else
        actual_output=silent
    fi

    if [[ "${actual_head}" == "${expected_head}" ]] && [[ "${actual_output}" == "${expect_output}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %-9s %s\n" "[${actual_output}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect_output}" "${actual_output}" "${label}"
    fi
}

new_case() {
    case_number=$((case_number + 1))
    dir="${scratch}/${case_number}"
    mkdir -p "${dir}"
    make_repo "${dir}"
}

new_case
commit_empty "${dir}/repo" landed
worktree=$(add_worktree "${dir}" ahead)
out=$(run_hook "Created worktree at ${worktree} on branch worktree-ahead. The session is now working in the worktree.")
check "local master ahead of origin: fast-forward" "${worktree}" "$(git -C "${dir}/repo" rev-parse master)" "${out}" fires

new_case
worktree=$(add_worktree "${dir}" even)
out=$(run_hook "Created worktree at ${worktree} on branch worktree-even. The session is now working in the worktree.")
check "local master equals origin: leave alone" "${worktree}" "$(git -C "${dir}/repo" rev-parse origin/master)" "${out}" silent

new_case
commit_empty "${dir}/repo" local-only
clone_remote "${dir}" "${dir}/other"
commit_empty "${dir}/other" from-elsewhere
push_master "${dir}/other"
git -C "${dir}/repo" fetch --quiet origin
worktree=$(add_worktree "${dir}" diverged)
out=$(run_hook "Created worktree at ${worktree} on branch worktree-diverged. The session is now working in the worktree.")
check "local master diverged from origin: leave alone" "${worktree}" "$(git -C "${dir}/repo" rev-parse origin/master)" "${out}" silent

new_case
commit_empty "${dir}/repo" landed
worktree=$(add_worktree "${dir}" switched)
out=$(run_hook "Switched to worktree at ${worktree} on branch worktree-switched.")
check "switch into existing worktree: leave alone" "${worktree}" "$(git -C "${dir}/repo" rev-parse origin/master)" "${out}" silent

new_case
commit_empty "${dir}/repo" landed
worktree=$(add_worktree "${dir}" busy)
commit_empty "${worktree}" in-progress
busy_head=$(git -C "${worktree}" rev-parse HEAD)
out=$(run_hook "Created worktree at ${worktree} on branch worktree-busy. The session is now working in the worktree.")
check "worktree already moved off origin: leave alone" "${worktree}" "${busy_head}" "${out}" silent

echo
echo "${passes} passed, ${fails} failed"
if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
