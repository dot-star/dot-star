#!/usr/bin/env bash
#
# UserPromptSubmit hook: fork the session into a new Ghostty or Terminal.app window when the
# prompt asks for one, then block the prompt, so the parent session spends no
# turn on it and stays where it was. `fork`, `fork <task>` or `f <task>` opens
# a window running a clean `claude` passed the task.
#
# See fork_session_window.inc.sh for how the window opens.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/fork_session_window.inc.sh"

# Read every field in one jq call, since the hook runs on every prompt. Split
# on NUL so a multi-line prompt survives.
{
    IFS= read -r -d '' prompt
    IFS= read -r -d '' session_id
    IFS= read -r -d '' transcript_path
    IFS= read -r -d '' cwd
} < <(
    command jq \
        --raw-output0 \
        '.prompt // "", .session_id // "", .transcript_path // "", .cwd // ""'
)

# Stop the prompt with a message shown to the user, never to the model. Use
# `continue: false` over `decision: "block"`, since a block puts the typed
# prompt back in the input field.
block() {
    command jq \
        --null-input \
        --compact-output \
        --arg reason "$1" \
        '{continue: false, stopReason: $reason}'
    exit 0
}

# Fork with the typed task when the prompt is a fork command.
fork_typed_task() {
    local prompt_lower
    local trigger_length
    local task
    local start_dir

    # Match `fork` alone or followed by a task, and `f` only followed by a task,
    # case-insensitively. Leave a bare `f` alone, since it already means fold.
    prompt_lower=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')
    if [[ "${prompt_lower}" =~ ^fork([[:space:]]|$) ]]; then
        trigger_length=4
    elif [[ "${prompt_lower}" =~ ^f[[:space:]]+[^[:space:]] ]]; then
        trigger_length=1
    else
        return 0
    fi

    # Strip the trigger word and the whitespace after it, keeping the task as typed.
    task="${prompt:${trigger_length}}"
    task="${task#"${task%%[![:space:]]*}"}"

    if ! start_dir=$(open_fork_window "${session_id}" "${transcript_path}" "${cwd}" "${task}"); then
        block "${start_dir}"
    fi

    block "Forked into a new window (${start_dir})."
}

fork_typed_task
