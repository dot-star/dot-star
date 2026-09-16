#!/usr/bin/env bash
#
# PostToolUse hook (Write|Edit): remind Claude to bank a personal context doc in
# its own repo after editing it. ai/contexts/private-* are gitignored symlinks
# and Edit/Write refuse symlinks, so the edit lands at the target and never
# shows in dot-star's `git status`. Fire once per file per session;
# warn_when_personal_context_untracked.sh catches anything still unbanked at
# SessionStart.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

input=$(cat)
file=$(command jq --raw-output '.tool_response.filePath // .tool_input.file_path // empty' <<<"${input}")
if [ -z "${file}" ]; then
    exit 0
fi

contexts_dir="${CLAUDE_CONTEXTS_DIR:-${HOME}/.dot-star/ai/contexts}"

# Echo the private-* link that resolves to <file>, or nothing when none does.
personal_context_link_for() {
    local file="$1"
    local link

    for link in "${contexts_dir}"/private-*; do
        if [ ! -L "${link}" ]; then
            continue
        elif [ "$(readlink -- "${link}")" = "${file}" ]; then
            echo "${link}"
            return 0
        fi
    done

    return 0
}

link="$(personal_context_link_for "${file}")"
if [ -z "${link}" ]; then
    exit 0
fi

sentinel_dir=$(claude_session_dir "$(command jq --raw-output '.session_id // empty' <<<"${input}")")
if [ -n "${sentinel_dir}" ]; then
    sentinel="${sentinel_dir}/reminded-personal-${file##*/}"
    if [ -e "${sentinel}" ]; then
        exit 0
    fi

    mkdir -p "${sentinel_dir}"
    : >"${sentinel}"
fi

repo="$(git -C "$(dirname -- "${file}")" rev-parse --show-toplevel 2>/dev/null || true)"
context="🔄 Edited a personal context doc: ${file} (reached from dot-star as ${link##*/})."
context+=$'\n'"dot-star ignores the symlink, so the edit only shows in ${repo:-its own repo}'s git status. Commit it there when the change is done and offer that in the follow-up menu."

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
