#!/usr/bin/env bash
# Exercise `rc_push` against a throwaway repo and bare remotes: every accepted
# argument shape must push the HEAD `s` stamped even when a commit lands between
# the guard and the push, and every other shape must be refused.
# Usage:
#   $ bash tools/version_control/.aliases_push_saved_head_test.sh [<checkout to test>]

set -euo pipefail

# Default to the checkout this script lives in.
checkout="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

root="$(command mktemp -d)"
trap 'rm -rf "${root}"' EXIT

cd "${root}"
git init \
    --quiet \
    --bare \
    --initial-branch=master \
    origin.git
git init \
    --quiet \
    --bare \
    --initial-branch=master \
    other.git
git init \
    --quiet \
    --initial-branch=master \
    repo
cd repo
git remote add origin ../origin.git
git remote add other ../other.git
git config push.default current

commit() {
    git \
        -c user.name="test" \
        -c user.email="test@example.com" \
        commit \
        --quiet \
        --allow-empty \
        --message="${1}"
}

commit "base"
git push \
    --quiet \
    --set-upstream \
    origin \
    master

source "${checkout}/tools/version_control/.aliases.sh" >/dev/null 2>&1 || true
set +e

# Load only the real default-branch lookup, rather than sourcing all of
# tools/bash/.aliases.sh, which ends a non-interactive shell.
eval "$(sed -n '/^git_default_branch() {$/,/^}$/p' "${checkout}/tools/bash/.aliases.sh")"

# Simulate a promote or merge landing after the guard passes: commit once the
# real guard returns, so a push that looks HEAD up again ships "sneaked in".
eval "$(declare -f rc_push_guard | sed '1s/rc_push_guard/real_rc_push_guard/')"
rc_push_guard() {
    real_rc_push_guard || return 1
    commit "sneaked in"
}

failures=0

pass() {
    echo "✓ ${1}"
}

fail() {
    echo "✗ ${1}"
    failures=$((failures + 1))
}

# Assert `rc_push <args>` pushed the stamped commit to <remote>'s <branch>.
expect_pushed() {
    local label="${1}"
    local remote_git="${2}"
    local branch="${3}"
    shift 3

    commit "reviewed ${label}"
    rc_push_guard_stamp
    local stamped
    stamped="$(git rev-parse HEAD)"

    local output
    output="$(rc_push "$@" 2>&1)"
    local status="${?}"

    local pushed
    pushed="$(git --git-dir="../${remote_git}" rev-parse --verify --quiet "refs/heads/${branch}")"

    if [[ "${status}" -ne 0 ]]; then
        fail "${label}: rc_push exited ${status}: ${output}"
    elif [[ "${pushed}" != "${stamped}" ]]; then
        fail "${label}: ${remote_git} ${branch} holds ${pushed}, not stamped ${stamped}"
    else
        pass "${label}: ${remote_git} ${branch} holds the stamped commit"
    fi
}

# Assert `rc_push <args>` refused and left every remote untouched.
expect_refused() {
    local label="${1}"
    shift 1

    commit "reviewed ${label}"
    rc_push_guard_stamp

    local before
    before="$(git --git-dir=../origin.git for-each-ref) $(git --git-dir=../other.git for-each-ref)"

    local output
    output="$(rc_push "$@" 2>&1)"
    local status="${?}"

    local after
    after="$(git --git-dir=../origin.git for-each-ref) $(git --git-dir=../other.git for-each-ref)"

    if [[ "${status}" -eq 0 ]]; then
        fail "${label}: rc_push succeeded"
    elif [[ "${before}" != "${after}" ]]; then
        fail "${label}: a remote changed"
    else
        pass "${label}: refused ($(echo "${output}" | head -1))"
    fi
}

echo "Main checkout:"
expect_pushed "no args" origin.git master
expect_pushed "<remote>" other.git master other
expect_pushed "<remote> <current branch>" origin.git master origin master
expect_refused "<remote> <other branch>" origin feature
expect_refused "flag" --force
expect_refused "refspec" origin master:feature
expect_refused "three args" origin master extra
expect_refused "unknown remote" nowhere

git branch --unset-upstream
expect_refused "no push remote"

# Publish the refused cases' leftovers, so the detached HEAD below is refused
# for being detached rather than for unpushed master commits under it.
git push --quiet origin master
git checkout --quiet --detach
expect_refused "detached HEAD" origin
git checkout --quiet master

# Publish the main-checkout cases' leftovers, so the worktree branches below
# start with no unpushed master commits under them.
git push --quiet origin master
echo

echo "Worktree branch, default-branch mode:"
git checkout --quiet -b worktree-fix-login master
DOTSTAR_WORKTREE_PUSH="default-branch" expect_pushed "push to default branch" origin.git master
echo

echo "Worktree branch, pr-branch mode:"
git checkout --quiet -b worktree-asmith+add-login master
DOTSTAR_WORKTREE_PUSH="pr-branch" expect_pushed "first push" origin.git asmith/add-login

upstream="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)"
if [[ "${upstream}" == "origin/asmith/add-login" ]]; then
    pass "first push: upstream set to ${upstream}"
else
    fail "first push: upstream is '${upstream}', not origin/asmith/add-login"
fi

DOTSTAR_WORKTREE_PUSH="pr-branch" expect_pushed "repeat push via upstream" origin.git asmith/add-login
echo

echo "Worktree branch carrying unpushed master commits:"
git checkout --quiet master

# Catch local master up with the default-branch push above, which moved only the remote's.
git fetch --quiet origin
git merge \
    --quiet \
    --ff-only \
    origin/master
git branch --quiet --set-upstream-to=origin/master master
commit "master only"

# Run from a real linked worktree, where `master` is checked out elsewhere.
git worktree add \
    --quiet \
    -b worktree-asmith+riders \
    ../riders-worktree
cd ../riders-worktree
commit "branch work"

DOTSTAR_WORKTREE_PUSH="pr-branch" expect_refused "push with master commits under HEAD"

# Run the rebase the refusal prints, the way a protected master leaves no other way out.
rc_push_guard_stamp
remedy="$(rc_push_guard | grep --only-matching 'git rebase --onto .*')"
if [[ "${remedy}" == "git rebase --onto origin/master master" ]]; then
    pass "refusal: names the rebase off master's upstream"
else
    fail "refusal: remedy is '${remedy}'"
fi
${remedy} --quiet

DOTSTAR_WORKTREE_PUSH="pr-branch" expect_pushed "push after the rebase" origin.git asmith/riders

if git --git-dir=../origin.git log --format='%s' refs/heads/asmith/riders | grep --quiet --line-regexp 'master only'; then
    fail "push after the rebase: master commit reached the pull request branch"
else
    pass "push after the rebase: master commit left out"
fi
echo

echo "Worktree branch carrying unpushed main commits:"

# Rebuild the layout under its own directory, so `../origin.git` names this repo's remote.
mkdir "${root}/main"
cd "${root}/main"
git init \
    --quiet \
    --bare \
    --initial-branch=main \
    origin.git
git init \
    --quiet \
    --bare \
    --initial-branch=main \
    other.git
git init \
    --quiet \
    --initial-branch=main \
    repo
cd repo
git remote add origin ../origin.git
commit "base"
git push \
    --quiet \
    --set-upstream \
    origin \
    main
commit "main only"

git worktree add \
    --quiet \
    -b worktree-asmith+main-riders \
    ../riders-worktree
cd ../riders-worktree
commit "branch work"

DOTSTAR_WORKTREE_PUSH="pr-branch" expect_refused "push with main commits under HEAD"

rc_push_guard_stamp
remedy="$(rc_push_guard | grep --only-matching 'git rebase --onto .*')"
if [[ "${remedy}" == "git rebase --onto origin/main main" ]]; then
    pass "refusal: names the rebase off main's upstream"
else
    fail "refusal: remedy is '${remedy}'"
fi
echo

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed"
    exit 1
fi

echo "All checks passed"
