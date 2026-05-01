#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl, reads the most recent
# `{"type":"custom-title", ...}` entry from each file, and lists sessions for
# confirmation before removal.

set -euo pipefail

source "${HOME}/.dot-star/bash/.confirm_prompts.sh"

target_title="ok-to-delete"
projects_dir="${HOME}/.claude/projects"

if [[ ! -d "${projects_dir}" ]]; then
    echo "Error: ${projects_dir} does not exist"
    exit 1
fi

matches=()
while IFS= read -r -d '' file; do
    title="$(
        \jq -r 'select(.type == "custom-title") | .customTitle' "${file}" 2>/dev/null |
            tail -n 1
    )"
    if [[ "${title}" == "${target_title}" ]]; then
        matches+=("${file}")
    fi
done < <(find "${projects_dir}" -type f -name '*.jsonl' -print0)

if [[ "${#matches[@]}" -eq 0 ]]; then
    echo "No sessions with customTitle \"${target_title}\" found."
    exit 0
fi

echo "Found ${#matches[@]} session(s) with customTitle \"${target_title}\":"
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
