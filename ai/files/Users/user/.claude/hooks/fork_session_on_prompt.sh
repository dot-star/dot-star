#!/usr/bin/env bash
#
# UserPromptSubmit hook: fork the session into a new Ghostty window when the
# prompt asks for one, then block the prompt, so the parent session spends no
# turn on it and stays where it was. The triggers run in order and the first
# match wins, so a prompt matching both opens one window:
#
#   1. `fork`, `fork <task>` or `f <task>`: the window runs a clean `claude`
#      passed the task.
#   2. A link to a failed GitHub Actions run: the window investigates and fixes
#      it. Each run forks once, so linking it again (the fork's own first prompt
#      included) reaches the session as usual.
#
# See fork_session_window.inc.sh for how the window opens.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/fork_session_window.inc.sh"

input=$(cat)
prompt=$(command jq --raw-output '.prompt // empty' <<<"${input}")
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

# Fork a fix for the failed GitHub Actions run the prompt links, once per run.
fork_failed_run_fix() {
    local run_url_pattern='https://github\.com/([^/[:space:]]+)/([^/[:space:]]+)/actions/runs/([0-9]+)(/job/[0-9]+)?'
    local run_url
    local owner
    local repo
    local run_id
    local seen_file
    local conclusion
    local task
    local start_dir

    if [[ ! "${prompt}" =~ ${run_url_pattern} ]]; then
        return 0
    fi

    run_url="${BASH_REMATCH[0]}"
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    run_id="${BASH_REMATCH[3]}"
    seen_file="${XDG_CACHE_HOME:-${HOME}/.cache}/dot-star/investigations/ci_runs/${owner}_${repo}_${run_id}"

    if [ -e "${seen_file}" ]; then
        return 0
    fi

    # Fork only for a run that actually failed; a link to a passing or unfinished run, or no answer from gh, lets the prompt through.
    if ! conclusion=$(
        gh run view "${run_id}" \
            --repo "${owner}/${repo}" \
            --json conclusion \
            --jq '.conclusion' 2>/dev/null
    ); then
        return 0
    elif [ "${conclusion}" != "failure" ]; then
        return 0
    fi

    task="Investigate and fix the failed GitHub Actions run ${run_url} (${owner}/${repo}, run ${run_id})."
    task+=" Pull the failing logs with: gh run view ${run_id} --repo ${owner}/${repo} --log-failed"
    task+=" Find the cause, fix it in a worktree of that repo and commit. Don't push; leave that to me."

    # Let the prompt through when the window can't open, so this session handles the run instead of losing the prompt.
    if ! start_dir=$(open_fork_window "${session_id}" "${transcript_path}" "${cwd}" "${task}"); then
        command jq \
            --null-input \
            --compact-output \
            --arg message "Didn't fork a CI investigation: ${start_dir}" \
            '{systemMessage: $message}'
        exit 0
    fi

    mkdir -p "${seen_file%/*}"
    : >"${seen_file}"

    block "Forked an investigation of failed run ${run_id} (${owner}/${repo}) into a new window (${start_dir})."
}

fork_typed_task
fork_failed_run_fix
