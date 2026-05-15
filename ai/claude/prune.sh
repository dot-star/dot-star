#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl, reads the most recent
# `{"type":"custom-title", ...}` entry from each file, and removes any session
# whose title matches a target.

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

before="$(count_sessions)"

matches=()
while IFS= read -r -d '' file; do
    # Pre-filter with grep so jq parses only the last match, not the whole transcript.
    title="$(
        { grep '"type":"custom-title"' "${file}" 2>/dev/null || true; } |
            tail -n 1 |
            \jq -r '.customTitle // empty'
    )"
    if is_target_title "${title}"; then
        matches+=("${file}")
    fi
done < <(find "${projects_dir}" -type f -name '*.jsonl' -print0)

quoted_titles="$(printf '"%s", ' "${target_titles[@]}")"
quoted_titles="${quoted_titles%, }"

if [[ "${#matches[@]}" -eq 0 ]]; then
    echo "No sessions with customTitle in {${quoted_titles}} found."
    exit 0
fi

echo "Pruning ${#matches[@]} session(s) with customTitle in {${quoted_titles}}:"
for file in "${matches[@]}"; do
    rm -v "${file}"
done

after="$(count_sessions)"
echo "Sessions: ${before} before, ${after} after ($((before - after)) pruned)."
