#!/usr/bin/env bash
# Tests for validate_bash_command.sh.
# Reads cases from validate_bash_command_test_cases.json (each entry is
# {name, cmd, expected}). For each case, feeds a synthetic Claude Code
# PreToolUse payload to the hook and asserts which decision it emits:
# `allow` (skip the prompt), `ask` (force one), or silence (fall-through to
# the normal permission flow).
#
# Run: bash ai/files/Users/user/.claude/hooks/validate_bash_command_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/validate_bash_command.sh"
CASES="${SCRIPT_DIR}/validate_bash_command_test_cases.json"

passes=0
fails=0
last_section=""

run_test() {
    local label="$1"
    local cmd="$2"
    local expect="$3"
    local out actual
    out=$(printf '%s' "${cmd}" | command jq --raw-input '{tool_input:{command:.}}' | "${HOOK}")
    if [ -n "${out}" ]; then
        actual=$(printf '%s' "${out}" | command jq --raw-output '.hookSpecificOutput.permissionDecision')
    else
        actual=fall-through
    fi
    if [ "${actual}" = "${expect}" ]; then
        passes=$((passes + 1))
        printf "  PASS  %-15s %s\n" "[${actual}]" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  expected=%s got=%s  %s\n" "${expect}" "${actual}" "${label}"
    fi
}

while IFS=$'\t' read -r name cmd expected; do
    cmd="${cmd//\\n/$'\n'}"
    cmd="${cmd//\\t/$'\t'}"
    if [ "${expected}" != "${last_section}" ]; then
        if [ -n "${last_section}" ]; then
            echo ""
        fi
        case "${expected}" in
        allow)
            echo "== Should ALLOW (safe-listed commands that need no prompt) =="
            ;;
        ask)
            echo "== Should ASK (gated here, where a rule cannot say 'except') =="
            ;;
        *)
            echo "== Should FALL THROUGH (everything else -> normal prompt) =="
            ;;
        esac
        last_section="${expected}"
    fi
    run_test "${name}" "${cmd}" "${expected}"
done < <(command jq --raw-output '.[] | [.name, .cmd, .expected] | @tsv' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
