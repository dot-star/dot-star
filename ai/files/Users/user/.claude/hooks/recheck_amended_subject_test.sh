#!/usr/bin/env bash
# Tests for recheck_amended_subject.sh. Feed a synthetic PostToolUse payload
# per case and assert whether the hook injects its reminder.
#
# Run: bash ai/files/Users/user/.claude/hooks/recheck_amended_subject_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/recheck_amended_subject.sh"

passes=0
fails=0

run_test() {
    local expect="${1}"
    local cmd="${2}"
    local out
    local actual

    out=$(command jq --null-input --arg cmd "${cmd}" '{tool_input:{command:$cmd}}' | "${HOOK}")
    if [ -n "${out}" ]; then
        actual=remind
    else
        actual=quiet
    fi

    if [ "${actual}" = "${expect}" ]; then
        passes=$((passes + 1))
        printf "  PASS  %-8s %s\n" "[${actual}]" "${cmd}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${cmd}"
    fi
}

echo "== Should REMIND (a commit was rewritten) =="
run_test remind "git commit --amend --no-edit"
run_test remind "git commit --amend -m subject"
run_test remind "git -C /path/to/repo commit --amend --no-edit --quiet"
run_test remind "git add -- file && git commit --amend --no-edit"
run_test remind "git merge --squash feature"
run_test remind "git rebase --autosquash HEAD~3"
run_test remind "git -c sequence.editor=true rebase -i --autosquash HEAD~3"

echo ""
echo "== Should stay QUIET (nothing was rewritten) =="
run_test quiet "git commit -m subject"
run_test quiet "git -C /path/to/repo add -- file"
run_test quiet "git -C /path/to/repo diff --cached --stat"
run_test quiet "echo git commit --amend"
run_test quiet "jq -n --arg c 'git commit --amend --all' '{tool_input:{command:\$c}}'"
run_test quiet "grep -n -- --amend notes.md"
run_test quiet "git merge feature"
run_test quiet "git rebase master"

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
