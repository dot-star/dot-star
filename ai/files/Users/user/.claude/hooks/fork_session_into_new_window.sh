#!/usr/bin/env bash
#
# UserPromptSubmit hook: fork the session into a new Ghostty window when the
# prompt is `fork` or `fork <task>`. The new window runs a clean `claude` (passed
# the task, when given) with the parent's session id and transcript path in its
# environment, where announce_fork_parent.sh picks them up at SessionStart. The
# prompt is then blocked, so the parent session spends no turn on it and stays
# where it was.
#
# The window opens in the main checkout, even from a worktree, so the fork never
# shares the parent's worktree; it makes its own. A window rather than a tab
# keeps the fork's separate objective out of the parent's tab bar.

set -euo pipefail

input=$(cat)
prompt=$(command jq --raw-output '.prompt // empty' <<<"${input}")

# Match `fork` alone or followed by whitespace and a task, case-insensitively.
prompt_lower=$(printf '%s' "${prompt}" | tr '[:upper:]' '[:lower:]')
if [[ ! "${prompt_lower}" =~ ^fork([[:space:]]|$) ]]; then
    exit 0
fi

# Strip the trigger word and the whitespace after it, keeping the task as typed.
task="${prompt:4}"
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

if [ "${TERM_PROGRAM:-}" != "ghostty" ]; then
    block "fork opens its window through Ghostty's AppleScript, so it only works under Ghostty (TERM_PROGRAM is '${TERM_PROGRAM:-unset}')."
fi

# Resolve the main checkout through the shared git dir, which every worktree points at.
start_dir="${cwd}"
if git_common_dir=$(git -C "${cwd}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    start_dir=$(dirname -- "${git_common_dir}")
fi

command_line="CLAUDE_FORKED_FROM=$(printf '%q' "${session_id}")"
command_line+=" CLAUDE_FORKED_TRANSCRIPT=$(printf '%q' "${transcript_path}")"
# Launch through `claude_run` rather than `claude`, so the window minimizes and
# closes once the fork's session ends, the same as `cl`.
command_line+=" claude_run"
if [ -n "${task}" ]; then
    command_line+=" $(printf '%q' "${task}")"
fi

# Pass both strings as arguments, so nothing in the task needs AppleScript escaping.
if ! error=$(
    osascript - "${start_dir}" "${command_line}"$'\n' 2>&1 <<'APPLESCRIPT'
on run argv
    tell application "Ghostty"
        new window with configuration {initial working directory:item 1 of argv, initial input:item 2 of argv}
    end tell
end run
APPLESCRIPT
); then
    block "fork couldn't open a Ghostty window: ${error}"
fi

block "Forked into a new window (${start_dir})."
