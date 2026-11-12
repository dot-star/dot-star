#!/usr/bin/env bash
#
# UserPromptSubmit hook: read a prompt holding nothing but a GitHub Actions run
# link as "look into the failure and propose a fix", and tell the session so.
# A link pasted among typed words passes through untouched, since the words
# already say what to do with it.

set -euo pipefail

prompt=$(command jq --raw-output '.prompt // ""')

# Match the whole prompt. Accept any tail after the run id (`/job/<id>`, `/attempts/<n>`, `?pr=<n>`, `#step:<n>:<line>`).
run_url_pattern='^https://github\.com/([^/[:space:]]+)/([^/[:space:]]+)/actions/runs/([0-9]+)([/?#][^[:space:]]*)?$'

# Strip the whitespace around the pasted link.
trimmed_prompt="${prompt#"${prompt%%[![:space:]]*}"}"
trimmed_prompt="${trimmed_prompt%"${trimmed_prompt##*[![:space:]]}"}"
if [[ ! "${trimmed_prompt}" =~ ${run_url_pattern} ]]; then
    exit 0
fi

run_url="${BASH_REMATCH[0]}"
owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
run_id="${BASH_REMATCH[3]}"

context="The prompt is a bare link to GitHub Actions run ${run_id} in ${owner}/${repo} (${run_url})."
context+=$'\nRead it as: look into the failure and propose a fix.'
context+=$'\n'"Pull the failing logs with \`gh run view ${run_id} --repo ${owner}/${repo} --log-failed\`; when the link names a job, that job is the one to explain."
context+=$'\nFind the cause, then propose the fix and wait for a go-ahead before editing anything.'
context+=$'\nIf the run passed or is still running, say so instead.'

command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $context}}'
