#!/usr/bin/env bash
#
# UserPromptSubmit hook: when a prompt mentions a context doc's
# `claude-mention` keyword, inject a one-line reference pointing at the full
# doc in ai/contexts/ (not its content), once per session. The full doc loads
# in its own repo via CLAUDE.local.md @import; this just surfaces a pointer so
# Claude can read it on demand from anywhere.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/load_claude_md_supplementals.inc.sh"

input=$(cat)
prompt=$(command jq --raw-output '.prompt // empty' <<<"${input}")
session_id=$(command jq --raw-output '.session_id // empty' <<<"${input}")
session_id=${session_id//[^a-zA-Z0-9-]/}

if [ -z "${prompt}" ]; then
    exit 0
fi

contexts_dir="${CLAUDE_CONTEXTS_DIR:-${HOME}/.dot-star/ai/contexts}"
sentinel_dir="/tmp/claude/${session_id}"
mkdir -p "${sentinel_dir}"

# Lowercase the prompt once for case-insensitive keyword matching.
prompt_lower=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')

# Emit a pointer for each not-yet-referenced doc whose keyword the prompt
# mentions, and mark it so later prompts in the session don't repeat it.
context=""
referenced_files=""
while IFS= read -r file; do
    sentinel="${sentinel_dir}/referenced-${file##*/}"
    if [ -e "${sentinel}" ]; then
        continue
    fi
    keyword=$(claude_supplemental_mention_keyword "${file}")
    if [ -z "${keyword}" ]; then
        continue
    fi

    # Match any one of the marker's comma-separated keywords (case-insensitive substring).
    matched=""
    IFS=',' read -ra keyword_terms <<<"${keyword}"
    for term in "${keyword_terms[@]}"; do
        # Trim surrounding whitespace, then lowercase.
        term="${term#"${term%%[![:space:]]*}"}"
        term="${term%"${term##*[![:space:]]}"}"
        term_lower=$(printf '%s' "${term}" |
            tr '[:upper:]' '[:lower:]')
        if [ -n "${term_lower}" ] && [[ "${prompt_lower}" == *"${term_lower}"* ]]; then
            matched="${term}"
            break
        fi
    done

    if [ -z "${matched}" ]; then
        continue
    fi

    title=$(sed -n 's/^# *//p' "${file}" | head -n 1)
    context+="Relevant context (\"${matched}\" mentioned): read ${file} (${title}) if useful."$'\n'
    referenced_files+="${file##*/} "
    touch "${sentinel}"
done < <(ls "${contexts_dir}"/*.md 2>/dev/null | sort --version-sort)

claude_supplemental_emit "${context}" "UserPromptSubmit" "${referenced_files% }"
