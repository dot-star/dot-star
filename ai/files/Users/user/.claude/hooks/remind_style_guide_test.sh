#!/usr/bin/env bash
# Tests for remind_style_guide.sh.
#
# Checks that every guide and context doc the hook names exists in the repo, so
# a renamed doc fails here instead of leaving the hook pointing at nothing, then
# feeds synthetic PreToolUse payloads and asserts which docs the reminder names.
#
# Run: bash ai/files/Users/user/.claude/hooks/remind_style_guide_test.sh

set -u

# Resolve symlinks so the contexts dir is found when run via ~/.claude/hooks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="${SCRIPT_DIR}/remind_style_guide.sh"
STYLES_DIR="$(cd "${SCRIPT_DIR}/../styles" && pwd)"
CONTEXTS_DIR="$(cd "${SCRIPT_DIR}/../../../../../contexts" && pwd)"

# Stop when the hook is missing; a hook that fails to run emits nothing, so
# every silent case would pass.
if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

passes=0
fails=0

pass() {
    passes=$((passes + 1))
    printf "  PASS  %s\n" "$1"
}

fail() {
    fails=$((fails + 1))
    printf "  FAIL  %s\n" "$1"
}

# Check each doc the hook appends lives where the reminder says it does.
check_mapped_docs() {
    local line
    local doc

    echo "== Every mapped doc exists =="
    while IFS= read -r line; do
        if [[ "${line}" =~ guides\+=\(\"([^\"]+)\"\) ]]; then
            doc="${BASH_REMATCH[1]}"
            if [[ -f "${STYLES_DIR}/${doc}" ]]; then
                pass "styles/${doc}"
            else
                fail "styles/${doc} named by the hook but missing"
            fi
        elif [[ "${line}" =~ context_docs\+=\(\"([^\"]+)\"\) ]]; then
            doc="${BASH_REMATCH[1]}"
            if [[ -f "${CONTEXTS_DIR}/${doc}" ]]; then
                pass "contexts/${doc}"
            else
                fail "contexts/${doc} named by the hook but missing"
            fi
        fi
    done <"${HOOK}"
}

# Feed one payload and assert the reminder names the doc, or stays silent.
run_case() {
    local tool_name="$1"
    local file_path="$2"
    local expect="$3"
    local out

    out=$(command jq --null-input --compact-output \
        --arg tool_name "${tool_name}" \
        --arg file_path "${file_path}" \
        '{tool_name: $tool_name, tool_input: {file_path: $file_path}}' |
        "${HOOK}")

    if [[ "${expect}" == "silent" ]]; then
        if [[ -z "${out}" ]]; then
            pass "${tool_name} ${file_path}: silent"
        else
            fail "${tool_name} ${file_path}: expected silent, got ${out}"
        fi
    elif [[ "${out}" == *"${expect}"* ]]; then
        pass "${tool_name} ${file_path}: names ${expect}"
    else
        fail "${tool_name} ${file_path}: expected ${expect}, got ${out:-nothing}"
    fi
}

check_mapped_docs

echo ""
echo "== Reminder names the matching doc =="
run_case Edit /repo/README.md silent
run_case Edit /repo/TODO.md todo-banking.md
run_case Edit /repo/notes/todo.md todo-banking.md
run_case Edit /repo/script.sh shell-style.md
run_case Edit /repo/script.sh code-style.md
run_case Edit /repo/tool_test.py python-test-style.md
run_case Edit todo.md todo-banking.md
run_case Write /repo/new.md file-naming-style.md

echo ""
echo "== Reminder asks for a trim on docs loaded into context =="
run_case Edit /repo/CLAUDE.md "trim it"
run_case Edit /home/.claude/CLAUDE_extra.md "trim it"
run_case Edit /repo/ai/contexts/shorthand.md "trim it"
run_case Edit /home/.claude/projects/repo/memory/feedback_foo.md "trim it"
run_case Edit /repo/skills/commit/SKILL.md "trim it"
run_case Write /repo/ai/contexts/new.md file-naming-style.md
run_case Write /repo/ai/contexts/new.md "trim it"
run_case Edit /repo/docs/guide.md silent

echo ""
echo "Passed: ${passes}  Failed: ${fails}"
if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
