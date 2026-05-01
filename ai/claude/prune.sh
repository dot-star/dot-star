#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl, reads the most recent
# `{"type":"custom-title", ...}` entry from each file, and lists sessions for
# confirmation before removal.

set -euo pipefail

source "${HOME}/.dot-star/bash/.confirm_prompts.sh"

target_titles=("ok-to-delete" "ok-to-del" "delete" "del" "tmp")
projects_dir="${HOME}/.claude/projects"

if [[ ! -d "${projects_dir}" ]]; then
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

matches=()
while IFS= read -r -d '' file; do
    title="$(
        \jq -r 'select(.type == "custom-title") | .customTitle' "${file}" 2>/dev/null |
            tail -n 1
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

echo "Found ${#matches[@]} session(s) with customTitle in {${quoted_titles}}:"
for file in "${matches[@]}"; do
    echo "  ${file}"
done
echo

reply="$(display_confirm_prompt_destructive "Prune these ${#matches[@]} session(s)? [y/N]")"
echo
if [[ "${reply}" =~ ^[Yy]$ ]]; then
    for file in "${matches[@]}"; do
        rm -v "${file}"
    done
else
    echo "Aborted."
fi
