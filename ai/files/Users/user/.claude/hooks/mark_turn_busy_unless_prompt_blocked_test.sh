#!/usr/bin/env bash
# Tests for mark_turn_busy_unless_prompt_blocked.sh.
# Runs a copy of the hook beside stub sibling hooks, so no real window opens and
# no real session state gets written, and asserts the hook's answer and whether
# it marked the session busy.
#
# Run: bash ai/files/Users/user/.claude/hooks/mark_turn_busy_unless_prompt_blocked_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_NAME="mark_turn_busy_unless_prompt_blocked.sh"
BLOCK_ANSWER='{"decision":"block","reason":"Forked into a new window (/tmp)."}'

passes=0
fails=0

# Write a stub blocking hook that answers with the given text, or nothing when
# empty, then exits with the given status.
write_blocking_stub() {
    local stub_dir="$1"
    local answer="$2"
    local exit_status="$3"
    local stub="${stub_dir}/fork_session_on_prompt.sh"

    printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf %%s %q\nexit %d\n' "${answer}" "${exit_status}" >"${stub}"
    chmod +x "${stub}"
}

# Write a silent stub for every blocking hook the wrapper lists, so a hook added
# to the list never runs for real or goes missing from the stub dir.
write_silent_blocking_stubs() {
    local stub_dir="$1"
    local hook

    while IFS= read -r hook; do
        printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"${stub_dir}/${hook}"
        chmod +x "${stub_dir}/${hook}"
    done < <(sed -n '/^blocking_hooks=(/,/^)/s/^ *"\(.*\)"$/\1/p' "${SCRIPT_DIR}/${HOOK_NAME}")
}

# Write a stub state hook that records its argument and the payload it read.
write_state_stub() {
    local stub_dir="$1"
    local stub="${stub_dir}/announce_window_state.py"

    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >"%s/state_call"\ncat >>"%s/state_call"\n' "${stub_dir}" "${stub_dir}" >"${stub}"
    chmod +x "${stub}"
}

run_test() {
    local label="$1"
    local blocker_answer="$2"
    local blocker_exit_status="$3"
    local expected_answer="$4"
    local expected_state_call="$5"
    local stub_dir
    local answer
    local state_call

    stub_dir=$(mktemp -d)
    cp "${SCRIPT_DIR}/${HOOK_NAME}" "${stub_dir}/"
    write_silent_blocking_stubs "${stub_dir}"
    write_blocking_stub "${stub_dir}" "${blocker_answer}" "${blocker_exit_status}"
    write_state_stub "${stub_dir}"

    answer=$(printf '%s' '{"prompt":"hello"}' | "${stub_dir}/${HOOK_NAME}")

    state_call=""
    if [[ -f "${stub_dir}/state_call" ]]; then
        state_call=$(cat "${stub_dir}/state_call")
    fi
    rm -r "${stub_dir}"

    if [[ "${answer}" != "${expected_answer}" ]]; then
        fails=$((fails + 1))
        printf "  FAIL  answer=%q expected=%q  %s\n" "${answer}" "${expected_answer}" "${label}"
    elif [[ "${state_call}" != "${expected_state_call}" ]]; then
        fails=$((fails + 1))
        printf "  FAIL  state call=%q expected=%q  %s\n" "${state_call}" "${expected_state_call}" "${label}"
    else
        passes=$((passes + 1))
        printf "  PASS  %s\n" "${label}"
    fi
}

run_test \
    "prompt nothing blocks marks the session busy" \
    "" \
    0 \
    "" \
    $'UserPromptSubmit\n{"prompt":"hello"}'
run_test \
    "prompt a hook blocks passes the block on without marking busy" \
    "${BLOCK_ANSWER}" \
    0 \
    "${BLOCK_ANSWER}" \
    ""
run_test \
    "prompt whose blocking hook crashes mid-answer still marks the session busy" \
    '{"decision":' \
    1 \
    "" \
    $'UserPromptSubmit\n{"prompt":"hello"}'

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
