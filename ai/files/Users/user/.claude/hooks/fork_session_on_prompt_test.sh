#!/usr/bin/env bash
# Tests for fork_session_on_prompt.sh.
# Reads cases from fork_session_on_prompt_test_cases.json (each entry is
# {name, prompt, expected}). For each case, feeds a synthetic Claude Code
# UserPromptSubmit payload to the hook and asserts whether it forks or lets the
# prompt pass through to the session.
#
# Run: bash ai/files/Users/user/.claude/hooks/fork_session_on_prompt_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/fork_session_on_prompt.sh"
CASES="${SCRIPT_DIR}/fork_session_on_prompt_test_cases.json"

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

    # Run outside Ghostty and Terminal.app, so a matched prompt gets blocked before any window opens.
    out=$(
        command jq \
            --null-input \
            --arg prompt "${prompt}" \
            '{prompt: $prompt, session_id: "12345678-90ab-cdef-1234-567890abcdef", transcript_path: "/tmp/transcript.jsonl", cwd: "/tmp"}' |
            TERM_PROGRAM=not-ghostty "${HOOK}"
    )

    if [[ -n "${out}" ]]; then
        actual=fork
    else
        actual=pass-through
    fi

    if [[ "${actual}" == "${expect}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %-15s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

# Read one compact case per line, since a prompt may hold a tab or newline that TSV would split.
while IFS= read -r case_json; do
    name=$(command jq --raw-output '.name' <<<"${case_json}")
    prompt=$(command jq --raw-output '.prompt' <<<"${case_json}")
    expected=$(command jq --raw-output '.expected' <<<"${case_json}")

    if [[ "${expected}" != "${last_section}" ]]; then
        if [[ -n "${last_section}" ]]; then
            echo ""
        fi

        if [[ "${expected}" == "fork" ]]; then
            echo "== Should FORK (fork alone, or fork or f followed by a task) =="
        else
            echo "== Should PASS THROUGH (bare f, fold picks, or no fork prefix) =="
        fi

        last_section="${expected}"
    fi

    run_test "${name}" "${prompt}" "${expected}"
done < <(command jq --compact-output '.[]' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
