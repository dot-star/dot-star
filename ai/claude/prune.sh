#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl and removes any session that is either:
#   - tagged with a customTitle in the target list (set via /rename), or
#   - a print-mode transcript (one-shot `claude --print` run, e.g. from `cmc`
#     or `ask`), identified by a queue-operation first event.

set -euo pipefail

echo "Pruning Claude sessions"

target_titles=("ok-to-delete" "ok-to-del" "delete" "del" "d" "tmp")
projects_dir="${HOME}/.claude/projects"

if [[ ! -d "${projects_dir}" ]]; then
    echo "Error: ${projects_dir} does not exist"
    exit 1
fi

count_sessions() {
    find "${projects_dir}" -type f -name '*.jsonl' |
        wc -l |
        tr -d ' '
}

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

before="$(count_sessions)"

matches=()
title_matches=0
print_matches=0
while IFS= read -r -d '' file; do
    # Pre-filter with grep so jq parses only the last match, not the whole transcript.
    title="$(
        { grep '"type":"custom-title"' "${file}" 2>/dev/null || true; } |
            tail -n 1 |
            \jq -r '.customTitle // empty'
    )"
    if is_target_title "${title}"; then
        matches+=("${file}")
        title_matches=$((title_matches + 1))
    elif is_print_mode_transcript "${file}"; then
        matches+=("${file}")
        print_matches=$((print_matches + 1))
    fi
done < <(find "${projects_dir}" -type f -name '*.jsonl' -print0)

if [[ "${#matches[@]}" -eq 0 ]]; then
    echo "No prunable sessions found."
    exit 0
fi

echo "Pruning ${#matches[@]} session(s) (${title_matches} tagged, ${print_matches} print-mode):"
for file in "${matches[@]}"; do
    rm -v "${file}"
done

after="$(count_sessions)"
echo "Sessions: ${before} before, ${after} after ($((before - after)) pruned)."
