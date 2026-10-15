#!/usr/bin/env bash
#
# UserPromptSubmit hook: fork the session into a new Ghostty window when the
# prompt is `fork`, `fork <task>` or `f <task>`. The new window runs a clean
# `claude` (passed the task, when given); see fork_session_window.inc.sh for how
# it opens. The prompt is then blocked, so the parent session spends no turn on
# it and stays where it was.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/fork_session_window.inc.sh"

input=$(cat)
prompt=$(command jq --raw-output '.prompt // empty' <<<"${input}")

# Match `fork` alone or followed by a task, and `f` only followed by a task,
# case-insensitively. Leave a bare `f` alone, since it already means fold.
prompt_lower=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')
if [[ "${prompt_lower}" =~ ^fork([[:space:]]|$) ]]; then
    trigger_length=4
elif [[ "${prompt_lower}" =~ ^f[[:space:]]+[^[:space:]] ]]; then
    trigger_length=1
else
    exit 0
fi

# Strip the trigger word and the whitespace after it, keeping the task as typed.
task="${prompt:${trigger_length}}"
task="${task#"${task%%[![:space:]]*}"}"

session_id=$(command jq --raw-output '.session_id // empty' <<<"${input}")
transcript_path=$(command jq --raw-output '.transcript_path // empty' <<<"${input}")
cwd=$(command jq --raw-output '.cwd // empty' <<<"${input}")

# Block the prompt with a message shown to the user, never to the model.
block() {
    command jq \
        --null-input \
        --compact-output \
        --arg reason "$1" \
        '{decision: "block", reason: $reason}'
    exit 0
}

if ! start_dir=$(open_fork_window "${session_id}" "${transcript_path}" "${cwd}" "${task}"); then
    block "${start_dir}"
fi

block "Forked into a new window (${start_dir})."
