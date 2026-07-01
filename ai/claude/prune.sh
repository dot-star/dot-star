#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl and removes any session that is either:
#   - tagged with a customTitle in the target list (set via /rename), or
#   - a print-mode transcript (one-shot `claude --print` run, e.g. from `cmc`
#     or `ask`), identified by a queue-operation first event.

set -euo pipefail

printf '🟡 Pruning Claude sessions...'

target_titles=("ok-to-delete" "ok-to-del" "delete" "del" "d" "tmp")
projects_dir="${HOME}/.claude/projects"

if [[ ! -d "${projects_dir}" ]]; then
    printf '\r\033[K'
    echo "Error: ${projects_dir} does not exist"
    exit 1
fi

is_target_title() {
    local candidate="${1}"
    local target
    for target in "${target_titles[@]}"; do
        if [[ "${candidate}" == "${target}" ]]; then
            return 0
        fi
    done
    return 1
}

# True if the file is a `claude --print` transcript (not a resumable session).
is_print_mode_transcript() {
    local file="${1}"
    local first_type
    first_type="$(
        head -n 1 "${file}" 2>/dev/null |
            \jq -r '.type // empty' 2>/dev/null
    )"
    if [[ "${first_type}" == "queue-operation" ]]; then
        return 0
    fi
    return 1
}

# True if the file is a resumable session, i.e. carries at least one main-thread
# (non-sidechain) event. Subagent transcripts are entirely sidechain, so they
# never match; this counts the same sessions the `claude --resume` picker lists.
is_resumable_session() {
    local file="${1}"
    grep -q '"isSidechain":false' "${file}" 2>/dev/null
}

pruned=0
remaining=0
sessions=0
while IFS= read -r -d '' file; do
    # Pre-filter with grep so jq parses only the last match, not the whole transcript.
    title="$(
        { grep '"type":"custom-title"' "${file}" 2>/dev/null || true; } |
            tail -n 1 |
            \jq -r '.customTitle // empty'
    )"
    if is_target_title "${title}"; then
        rm "${file}"
        pruned=$((pruned + 1))
    elif is_print_mode_transcript "${file}"; then
        rm "${file}"
        pruned=$((pruned + 1))
    else
        remaining=$((remaining + 1))
        if is_resumable_session "${file}"; then
            sessions=$((sessions + 1))
        fi
    fi
done < <(find "${projects_dir}" -type f -name '*.jsonl' -print0)

printf '\r\033[K\033[90m⚪️ Pruning Claude sessions... done (%d pruned, %d remaining, %d sessions)\033[0m\n' "${pruned}" "${remaining}" "${sessions}"
