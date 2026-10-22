#!/usr/bin/env bash
# PostToolUse hook (Bash): after a commit is amended or squashed, remind to
# re-check the subject. Folding changes in can leave the old summary stale.

set -u

source "$(dirname -- "${BASH_SOURCE[0]}")/git_command.inc.sh"

# Report whether a command in the line amends or squashes a commit. Match the
# git subcommand rather than the text, so a line merely mentioning `--amend`
# (an `echo`, a hook test payload) stays quiet.
rewrites_a_commit() {
    local segment
    local args

    split_commands "${1}"
    for segment in "${segments[@]}"; do
        if args="$(git_subcommand_args "${segment}" commit)" && [[ " ${args} " == *" --amend "* ]]; then
            return 0
        elif args="$(git_subcommand_args "${segment}" merge)" && [[ " ${args} " == *" --squash "* ]]; then
            return 0
        elif args="$(git_subcommand_args "${segment}" rebase)" && [[ " ${args} " == *" --autosquash "* ]]; then
            return 0
        fi
    done

    return 1
}

cmd=$(command jq --raw-output '.tool_input.command // empty')

# Fire only for amend/squash; every other command passes through untouched.
if ! rewrites_a_commit "${cmd}"; then
    exit 0
fi

# Inject the nudge; PostToolUse additionalContext lands in the next turn.
reminder="A commit was just amended or squashed: re-read the result (git show --stat HEAD) and rewrite the subject with git commit --amend if the folded-in changes no longer match it."
command jq -nc --arg msg "${reminder}" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$msg}}'
