#!/usr/bin/env bash
# Tests for inject_status_shorthand_pointer.sh.
# Reads cases from inject_status_shorthand_pointer_test_cases.json (each entry
# is {expected, name, prompt}). For each case, feeds a synthetic Claude Code
# UserPromptSubmit payload to the hook and asserts whether it emits a pointer at
# the status shorthand or stays silent.
#
# Pin the near-misses especially. The word-boundary regex is spelled out by hand
# for portability, so a careless edit that drops it would fire on every
# "status" the user types.
#
# Run: bash ai/files/Users/user/.claude/hooks/inject_status_shorthand_pointer_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/inject_status_shorthand_pointer.sh"
CASES="${SCRIPT_DIR}/inject_status_shorthand_pointer_test_cases.json"

# Stop when the hook is missing. A hook that fails to run emits nothing, which
# is indistinguishable from a deliberate silence, so every silent case would
# pass against a hook that isn't even there.
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
    local payload
    local out
    local actual

    payload=$(command jq \
        --null-input \
        --compact-output \
        --arg prompt "${prompt}" \
        '{prompt: $prompt}')
    out=$(printf '%s' "${payload}" | "${HOOK}")

    if [[ -n "${out}" ]]; then
        actual=fires
    else
        actual=silent
    fi

    if [[ "${actual}" == "${expect}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %-9s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

while IFS=$'\t' read -r expected name prompt; do
    if [[ "${expected}" != "${last_section}" ]]; then
        if [[ -n "${last_section}" ]]; then
            echo ""
        fi

        if [[ "${expected}" == "fires" ]]; then
            echo "== Should FIRE (the prompt mentions the token as its own word) =="
        else
            echo "== Should STAY SILENT (no standalone mention) =="
        fi

        last_section="${expected}"
    fi

    run_test "${name}" "${prompt}" "${expected}"
done < <(command jq --raw-output '.[] | [.expected, .name, .prompt] | @tsv' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
