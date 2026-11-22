#!/usr/bin/env bash
# Tests for enforce_executable_bit.sh.
# Builds a throwaway git repo, feeds the hook a synthetic PostToolUse payload per
# case and asserts the mode it leaves plus whether it reports the flip.
#
# Run: bash ai/files/Users/user/.claude/hooks/enforce_executable_bit_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/enforce_executable_bit.sh"

# Stop when the hook is missing: a hook that fails to run emits nothing, so every
# silent case would pass.
if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

repo="$(mktemp -d)"
trap 'rm -r "${repo}"' EXIT
git -C "${repo}" init --quiet

passes=0
fails=0

# Create a file with the given content and mode, committing it when tracked.
make_file() {
    local name="$1"
    local content="$2"
    local mode="$3"
    local tracked="$4"

    printf '%s\n' "${content}" >"${repo}/${name}"
    command chmod "${mode}" "${repo}/${name}"

    if [[ "${tracked}" == "tracked" ]]; then
        git -C "${repo}" add -- "${name}"
        git \
            -C "${repo}" \
            -c user.name="test" \
            -c user.email="test@example.com" \
            commit \
            --quiet \
            --message "Add ${name}"
    fi
}

run_test() {
    local label="$1"
    local name="$2"
    local expect_mode="$3"
    local expect_report="$4"
    local out
    local actual_mode
    local actual_report

    out=$(
        command jq \
            --null-input \
            --compact-output \
            --arg file "${repo}/${name}" \
            '{tool_input: {file_path: $file}}' |
            bash "${HOOK}"
    )

    actual_mode="644"
    if [[ -x "${repo}/${name}" ]]; then
        actual_mode="755"
    fi

    actual_report="silent"
    if [[ "${out}" == *"additionalContext"* ]]; then
        actual_report="report"
    fi

    if [[ "${actual_mode}" == "${expect_mode}" ]] && [[ "${actual_report}" == "${expect_report}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %s\n" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  %s (want %s/%s, got %s/%s)\n" "${label}" "${expect_mode}" "${expect_report}" "${actual_mode}" "${actual_report}"
    fi
}

make_file "tracked_exec_data.js" "var a = 1;" "755" "tracked"
make_file "tracked_plain_data.js" "var a = 1;" "644" "tracked"
make_file "untracked_exec_data.js" "var a = 1;" "755" "untracked"
make_file "tracked_plain_script.sh" "#!/usr/bin/env bash" "644" "tracked"
make_file "tracked_exec_script.sh" "#!/usr/bin/env bash" "755" "tracked"
make_file ".tracked_exec_fragment.sh" "#!/usr/bin/env bash" "755" "tracked"

run_test "strips and reports a tracked 755 data file" "tracked_exec_data.js" "644" "report"
run_test "stays silent on a tracked 644 data file" "tracked_plain_data.js" "644" "silent"
run_test "strips an untracked 755 data file silently" "untracked_exec_data.js" "644" "silent"
run_test "grants and reports a tracked 644 script" "tracked_plain_script.sh" "755" "report"
run_test "stays silent on a tracked 755 script" "tracked_exec_script.sh" "755" "silent"
run_test "strips and reports a tracked 755 sourced fragment" ".tracked_exec_fragment.sh" "644" "report"

echo
echo "${passes} passed, ${fails} failed"

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
