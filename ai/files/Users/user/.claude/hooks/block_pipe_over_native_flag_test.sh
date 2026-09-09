#!/usr/bin/env bash
# Tests for block_pipe_over_native_flag.sh.
# Reads cases from block_pipe_over_native_flag_test_cases.json (each entry is
# {name, cmd, expected}). For each case, feeds a synthetic Claude Code
# PreToolUse payload to the hook and asserts whether it emits a deny decision
# or stays silent (fall-through to the normal permission flow).
#
# Run: bash ai/files/Users/user/.claude/hooks/block_pipe_over_native_flag_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/block_pipe_over_native_flag.sh"
CASES="${SCRIPT_DIR}/block_pipe_over_native_flag_test_cases.json"

# Stop when the hook is missing. A hook that fails to run emits nothing, which
# is indistinguishable from a fall-through, so every allow case would pass.
if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

passes=0
fails=0
last_section=""

run_test() {
    local label="$1"
    local cmd="$2"
    local expect="$3"
    local out
    local actual

    out=$(printf '%s' "${cmd}" | command jq --raw-input '{tool_input:{command:.}}' | "${HOOK}")

    if [[ -n "${out}" ]]; then
        actual=deny
    else
        actual=fall-through
    fi

    if [[ "${actual}" == "${expect}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %-15s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

while IFS=$'\t' read -r name cmd expected; do
    if [[ "${expected}" != "${last_section}" ]]; then
        if [[ -n "${last_section}" ]]; then
            echo ""
        fi

        if [[ "${expected}" == "deny" ]]; then
            echo "== Should DENY (a pipe redoing what the command's own flag already does) =="
        else
            echo "== Should FALL THROUGH (no redundant pipe, or no equivalent flag) =="
        fi

        last_section="${expected}"
    fi

    run_test "${name}" "${cmd}" "${expected}"
done < <(command jq --raw-output '.[] | [.name, .cmd, .expected] | @tsv' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
