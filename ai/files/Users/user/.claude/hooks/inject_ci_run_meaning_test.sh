#!/usr/bin/env bash
# Tests for inject_ci_run_meaning.sh.
# Reads cases from inject_ci_run_meaning_test_cases.json (each entry is
# {name, prompt, expected}). For each case, feeds a synthetic Claude Code
# UserPromptSubmit payload to the hook and asserts whether it injects context
# or lets the prompt pass through untouched.
#
# Run: bash ai/files/Users/user/.claude/hooks/inject_ci_run_meaning_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/inject_ci_run_meaning.sh"
CASES="${SCRIPT_DIR}/inject_ci_run_meaning_test_cases.json"

# Stop when the hook is missing. A hook that fails to run emits nothing, which
# is indistinguishable from a pass-through, so every pass-through case would pass.
if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

passes=0
fails=0
last_section=""

run_test() {
    local label="$1"
    local prompt="$2"
    local expect="$3"
    local out
    local actual

    out=$(
        command jq \
            --null-input \
            --arg prompt "${prompt}" \
            '{prompt: $prompt, session_id: "12345678-90ab-cdef-1234-567890abcdef", cwd: "/tmp"}' |
            "${HOOK}"
    )

    # Count an injection only when the context names the run, so a malformed payload can't pass as one.
    if [[ "${out}" == *"run 1234567 in foo/bar"* ]]; then
        actual=inject
    elif [[ -z "${out}" ]]; then
        actual=pass-through
    else
        actual="unexpected output: ${out}"
    fi

    if [[ "${actual}" == "${expect}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %-15s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

# Read every case's fields from one jq call, split on NUL, since a prompt may hold a tab or newline that TSV would split.
while
    IFS= read -r -d '' name &&
        IFS= read -r -d '' prompt &&
        IFS= read -r -d '' expected
do

    if [[ "${expected}" != "${last_section}" ]]; then
        if [[ -n "${last_section}" ]]; then
            echo ""
        fi

        if [[ "${expected}" == "inject" ]]; then
            echo "== Should INJECT (a prompt holding nothing but a run link) =="
        else
            echo "== Should PASS THROUGH (a run link among typed words, or no run link) =="
        fi

        last_section="${expected}"
    fi

    run_test "${name}" "${prompt}" "${expected}"
done < <(
    command jq \
        --raw-output0 \
        '.[] | .name, .prompt, .expected' \
        "${CASES}"
)

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
