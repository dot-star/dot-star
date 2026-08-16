#!/usr/bin/env bash
# Tests for block_wrong_build_flags.sh.
# Reads cases from block_wrong_build_flags_test_cases.json (each entry is
# {name, cmd, tool, build, expected}). For each case, feeds a synthetic Claude
# Code PreToolUse payload to the hook and asserts whether it emits a deny
# decision or stays silent (fall-through to the normal permission flow).
#
# Skip a case whose declared build isn't the one installed: the hook reads the
# build off PATH, so the BSD cases can't fire on a GNU-only box and the GNU ones
# can't fire without Homebrew's coreutils. Cases declaring "any" never depend on
# a build and always run.
#
# Run: bash ai/files/Users/user/.claude/hooks/block_wrong_build_flags_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/block_wrong_build_flags.sh"
CASES="${SCRIPT_DIR}/block_wrong_build_flags_test_cases.json"

# Stop when the hook is missing. A hook that fails to run emits nothing, which
# is indistinguishable from a fall-through, so every allow case would pass.
if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

passes=0
fails=0
skips=0
last_section=""

# Name the build of the tool on PATH, matching the hook's own probe.
installed_build() {
    local tool="$1"

    if command "${tool}" --version </dev/null 2>&1 | command grep --quiet -- 'GNU'; then
        printf 'GNU'
    else
        printf 'BSD'
    fi
}

run_test() {
    local label="$1"
    local cmd="$2"
    local tool="$3"
    local build="$4"
    local expect="$5"
    local actual_build
    local out
    local actual

    if [[ "${build}" != "any" ]]; then
        actual_build=$(installed_build "${tool}")

        if [[ "${actual_build}" != "${build}" ]]; then
            skips=$((skips + 1))
            printf "  SKIP  %-15s %s (needs the %s %s, found the %s one)\n" "[skipped]" "${label}" "${build}" "${tool}" "${actual_build}"
            return
        fi
    fi

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

while IFS=$'\t' read -r name cmd tool build expected; do
    if [[ "${expected}" != "${last_section}" ]]; then
        if [[ -n "${last_section}" ]]; then
            echo ""
        fi

        if [[ "${expected}" == "deny" ]]; then
            echo "== Should DENY (flag spelling doesn't match the installed build) =="
        else
            echo "== Should FALL THROUGH (flag fits the build, or the tool isn't a candidate) =="
        fi

        last_section="${expected}"
    fi

    run_test "${name}" "${cmd}" "${tool}" "${build}" "${expected}"
done < <(command jq --raw-output '.[] | [.name, .cmd, .tool, .build, .expected] | @tsv' "${CASES}")

echo ""
echo "== Summary: ${passes} passed, ${fails} failed, ${skips} skipped =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
