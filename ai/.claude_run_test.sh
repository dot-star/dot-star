#!/usr/bin/env bash

# Check that claude_run dispatches each invocation to the right launch directory
# and claude flags, from both the main checkout and a linked worktree.
#
# Run: bash ai/.claude_run_test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the repo's main checkout rather than assuming the script's parent is
# one, so the out-of-worktree cases still test out-of-worktree behavior when the
# test itself runs from a linked worktree.
GIT_COMMON_DIR="$(git -C "${SCRIPT_DIR}" rev-parse --path-format=absolute --git-common-dir)"
MAIN_CHECKOUT="$(cd "$(dirname "${GIT_COMMON_DIR}")" && pwd -P)"

source "${SCRIPT_DIR}/.aliases.sh"

# Stub claude so nothing launches; report the launch dir, the args it would get,
# and the objective claude_run exported.
claude() {
    echo "$(pwd)|$*|${CLAUDE_OBJECTIVE:-}"
}

# Point HOME at a throwaway dir holding a no-op prune.sh, so the run doesn't
# sweep the real session store on the way out.
HOME="$(mktemp -d)"
export HOME
mkdir --parents "${HOME}/.dot-star/ai/claude"
echo '#!/usr/bin/env bash' >"${HOME}/.dot-star/ai/claude/prune.sh"
chmod +x "${HOME}/.dot-star/ai/claude/prune.sh"

# Attach a throwaway worktree to exercise the in-worktree branches.
WORKTREE_DIR="$(mktemp -d)/worktree"
git -C "${MAIN_CHECKOUT}" worktree add --detach --quiet "${WORKTREE_DIR}" HEAD
WORKTREE_DIR="$(cd "${WORKTREE_DIR}" && pwd -P)"

failures=0

assert_dispatch() {
    # Run claude_run in <dir> with the remaining args and compare the stub's
    # "<cwd>|<args>|<objective>" line against <expected>.
    local label="$1"
    local dir="$2"
    local expected="$3"
    shift 3

    # Confine the run to a subshell so an exported objective can't leak into the
    # next case.
    local actual
    actual="$(
        cd "${dir}" &&
            claude_run "$@"
    )"

    if [[ "${actual}" == "${expected}" ]]; then
        echo "✓ ${label}"
    else
        echo "✗ ${label}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        failures=$((failures + 1))
    fi
}

uuid="00000000-1111-2222-3333-444444444444"

assert_dispatch "worktree, bare cl continues its own session" \
    "${WORKTREE_DIR}" "${WORKTREE_DIR}|--continue|"
assert_dispatch "worktree, clr continues its own session" \
    "${WORKTREE_DIR}" "${WORKTREE_DIR}|--continue|" --resume
assert_dispatch "worktree, explicit --resume <uuid> passes through" \
    "${WORKTREE_DIR}" "${WORKTREE_DIR}|--resume ${uuid}|" --resume "${uuid}"
assert_dispatch "worktree, bare <uuid> resumes that session" \
    "${WORKTREE_DIR}" "${WORKTREE_DIR}|--resume ${uuid}|" "${uuid}"
assert_dispatch "worktree, other flags start a fresh session" \
    "${WORKTREE_DIR}" "${WORKTREE_DIR}|--some-flag|" --some-flag
assert_dispatch "main checkout, bare cl starts a fresh session" \
    "${MAIN_CHECKOUT}" "${MAIN_CHECKOUT}||"
assert_dispatch "main checkout, clr opens the picker" \
    "${MAIN_CHECKOUT}" "${MAIN_CHECKOUT}|--resume|" --resume
assert_dispatch "main checkout, clo labels the window" \
    "${MAIN_CHECKOUT}" "${MAIN_CHECKOUT}|--resume|ship it" --obj "ship it" --resume

git -C "${MAIN_CHECKOUT}" worktree remove --force "${WORKTREE_DIR}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
