#!/usr/bin/env bash
# Tests for check_bracket_prefix.sh.
#
# Reads cases from check_bracket_prefix_test_cases.json (each entry has
# {name, msg, stop, expected}). For each case, feeds a synthetic Claude Code
# Stop-hook payload to the hook and asserts whether the hook emits a block
# decision (any stdout output) or stays silent (clean exit 0).
#
# Run: bash ai/files/Users/user/.claude/hooks/check_bracket_prefix_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/check_bracket_prefix.sh"
CASES="${SCRIPT_DIR}/check_bracket_prefix_test_cases.json"

passes=0
fails=0
last_section=""

run_test() {
    local label="$1"
    local msg="$2"
    local stop="$3"
    local expect="$4"
    local input out actual

    input=$(command jq --null-input --compact-output \
        --arg msg "${msg}" \
        --argjson stop "${stop}" \
        '{last_assistant_message: $msg, stop_hook_active: $stop}')

    out=$(printf '%s' "${input}" | bash "${HOOK}")
    if [ -n "${out}" ]; then
        actual=block
    else
        actual=pass
    fi
    if [ "${actual}" = "${expect}" ]; then
        passes=$((passes + 1))
        printf "  PASS  %-9s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

while IFS= read -r case_json; do
    name=$(printf '%s' "${case_json}" | command jq --raw-output '.name')
    msg=$(printf '%s' "${case_json}" | command jq --raw-output '.msg')
    stop=$(printf '%s' "${case_json}" | command jq --raw-output '.stop')
    expected=$(printf '%s' "${case_json}" | command jq --raw-output '.expected')

    if [ "${expected}" != "${last_section}" ]; then
        if [ -n "${last_section}" ]; then
            echo ""
        fi
        if [ "${expected}" = "block" ]; then
            echo "== Should BLOCK (alternative-offering question without bracket prefix) =="
        else
            echo "== Should PASS (compliant, irrelevant, or guarded) =="
        fi
        last_section="${expected}"
    fi
    run_test "${name}" "${msg}" "${stop}" "${expected}"
done < <(command jq --compact-output '.[]' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
