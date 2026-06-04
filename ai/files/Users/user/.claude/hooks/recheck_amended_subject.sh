#!/usr/bin/env bash
# PostToolUse hook (Bash): after a commit is amended or squashed, remind to
# re-check the subject. Folding changes in can leave the old summary stale.

set -u

cmd=$(command jq --raw-output '.tool_input.command // empty')
# Fire only for amend/squash; every other command passes through untouched.
case "${cmd}" in
*--amend* | *"merge --squash"* | *--autosquash*) ;;
*) exit 0 ;;
esac

# Inject the nudge; PostToolUse additionalContext lands in the next turn.
reminder="A commit was just amended or squashed: re-read the result (git show --stat HEAD) and rewrite the subject with git commit --amend if the folded-in changes no longer match it."
command jq -nc --arg msg "${reminder}" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$msg}}'
