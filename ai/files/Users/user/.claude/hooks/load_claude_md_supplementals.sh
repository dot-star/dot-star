#!/usr/bin/env bash
#
# SessionStart hook: inject every ~/.claude/CLAUDE_*.md supplemental
# instruction file into session context, in version-sort order, so the
# base CLAUDE.md rule to read them each session is enforced by the harness
# instead of relying on the model to remember.

set -euo pipefail

claude_dir="${HOME}/.claude"

# Concatenate the supplemental files in version-sort order (numbered names
# numerically, un-numbered names alphabetically after), each under a header
# so its provenance is clear in context.
context=""
while IFS= read -r file; do
    context+="===== ${file} ====="$'\n'
    context+="$(cat "${file}")"$'\n\n'
done < <(ls "${claude_dir}"/CLAUDE_*.md 2>/dev/null | sort --version-sort)

if [ -z "${context}" ]; then
    exit 0
fi

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}'
