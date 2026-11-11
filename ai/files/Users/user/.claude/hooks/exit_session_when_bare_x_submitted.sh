#!/usr/bin/env bash
#
# UserPromptSubmit hook: close the session the moment a bare `x` or `xx` is
# submitted, when the close owes no work, so the window goes without waiting on
# a model reply. An `x` inside a git worktree still reaches the model, since it
# lands the worktree first. So does an `x` or `xx` sent while a turn is still
# running, so the close waits for that turn's work. Writes the prune mark the
# model would have, so prune.sh still sweeps the session.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

# Read every field in one jq call, since the hook runs on every prompt. Split
# on NUL so a multi-line prompt survives.
{
    IFS= read -r -d '' prompt
    IFS= read -r -d '' session_id
    IFS= read -r -d '' cwd
    IFS= read -r -d '' transcript_path
} < <(
    command jq \
        --raw-output0 \
        '.prompt // "", .session_id // "", .cwd // "", .transcript_path // ""'
)

# Succeed when the session sits in a linked worktree, whose git dir differs
# from the repo's common one.
is_inside_worktree() {
    local git_dirs
    local git_dir
    local common_dir

    # Treat a missing or non-repo cwd as outside, e.g. a worktree a land already tore down.
    if ! git_dirs=$(
        git -C "${cwd}" rev-parse \
            --path-format="absolute" \
            --absolute-git-dir \
            --git-common-dir \
            2>/dev/null
    ); then
        return 1
    fi

    {
        read -r git_dir
        read -r common_dir
    } <<<"${git_dirs}"
    [[ "${git_dir}" != "${common_dir}" ]]
}

# Succeed when the prompt closes the session without any work left for the model.
is_close_owing_no_work() {
    local reply

    # Trim surrounding whitespace and fold case, since a dictated prompt capitalizes at will.
    reply=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')
    reply="${reply#"${reply%%[![:space:]]*}"}"
    reply="${reply%"${reply##*[![:space:]]}"}"

    if [[ "${turn_before}" == "open" ]]; then
        return 1
    elif [[ "${reply}" == "xx" ]]; then
        return 0
    elif [[ "${reply}" != "x" ]]; then
        return 1
    elif is_inside_worktree; then
        return 1
    else
        return 0
    fi
}

if [[ -z "${session_id}" ]]; then
    exit 0
fi

# Check for a running turn before opening this prompt's own; the prune Stop
# hook closes it. Any prompt arriving mid-turn joins that turn.
turn_before=$(describe_turn "${session_id}")

mkdir --parents -- "${open_turns_dir}"
: >"${open_turns_dir}/${session_id}"

if ! is_close_owing_no_work; then
    exit 0
fi

# Leave the prompt to the model when no claude ancestor turns up, so the `x`
# isn't swallowed without a close.
claude_pid=$(find_claude_pid)
if [[ -z "${claude_pid}" ]]; then
    exit 0
fi

mkdir --parents -- "${prune_marks_dir}"
: >"${prune_marks_dir}/${session_id}"
log_session_close "bare ${prompt}" "${session_id}" "${cwd}" "${transcript_path}" "${turn_before}"
mark_close_requested
leave_full_screen_space "${session_id}" "${claude_pid}"

# Stop the prompt before it reaches the model. Use `continue: false` over
# `decision: "block"`, since a block puts the typed prompt back in the input.
command jq \
    --null-input \
    --compact-output \
    '{continue: false, stopReason: "Closing session."}'
rm --force -- "${open_turns_dir}/${session_id}"
kill -TERM "${claude_pid}"
