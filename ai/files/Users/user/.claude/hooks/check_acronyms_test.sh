#!/usr/bin/env bash
# Tests for check_acronyms.py.
#
# Reads cases from check_acronyms_test_cases.json (each entry has
# {name, msg, stop, expected} and an optional needs_dict). For each case, feeds
# a synthetic Claude Code Stop-hook payload to the hook and asserts whether the
# hook emits a block decision (any stdout output) or stays silent (clean exit
# 0). Cases marked needs_dict are skipped when /usr/share/dict/words is absent,
# since their outcome depends on the dictionary lookup.
#
# Run: bash ai/files/Users/user/.claude/hooks/check_acronyms_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/check_acronyms.py"
CASES="${SCRIPT_DIR}/check_acronyms_test_cases.json"

passes=0
fails=0
skips=0
last_section=""

have_dictionary() {
    [ -r /usr/share/dict/words ]
}

run_test() {
    local label="$1"
    local msg="$2"
    local stop="$3"
    local expect="$4"
    local needs_dict="$5"
    local input out actual

    if [ "${needs_dict}" = "true" ] && ! have_dictionary; then
        skips=$((skips + 1))
        printf "  SKIP  %-9s %s (no /usr/share/dict/words)\n" "[skip]" "${label}"
        return
    fi

    input=$(command jq --null-input --compact-output \
        --arg msg "${msg}" \
        --argjson stop "${stop}" \
        '{last_assistant_message: $msg, stop_hook_active: $stop}')

    out=$(printf '%s' "${input}" |
        python3 "${HOOK}")
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
    name=$(printf '%s' "${case_json}" |
        command jq --raw-output '.name')
    msg=$(printf '%s' "${case_json}" |
        command jq --raw-output '.msg')
    stop=$(printf '%s' "${case_json}" |
        command jq --raw-output '.stop')
    expected=$(printf '%s' "${case_json}" |
        command jq --raw-output '.expected')
    needs_dict=$(printf '%s' "${case_json}" |
        command jq --raw-output '.needs_dict // false')

    if [ "${expected}" != "${last_section}" ]; then
        if [ -n "${last_section}" ]; then
            echo ""
        fi
        if [ "${expected}" = "block" ]; then
            echo "== Should BLOCK (unexplained niche acronym in prose) =="
        else
            echo "== Should PASS (whitelisted, exempt region, spelled out, or guarded) =="
        fi
        last_section="${expected}"
    fi

    run_test "${name}" "${msg}" "${stop}" "${expected}" "${needs_dict}"
done < <(command jq --compact-output '.[]' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed, ${skips} skipped =="

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
