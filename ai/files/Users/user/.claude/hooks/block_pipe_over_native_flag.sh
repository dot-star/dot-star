#!/usr/bin/env bash
# PreToolUse hook: deny a pipeline that redoes work the upstream command already
# does through a flag of its own. The folded form is exactly equivalent and
# stays a single command, so validate_bash_command.sh can auto-allow it where
# the pipeline falls through to a permission prompt.

set -u

cmd=$(command jq --raw-output '.tool_input.command')

# Match a `gh api` fetch piped into a transform it already carries a flag for.
# Anchor on the pipe so a `base64` or `jq` naming itself elsewhere in the
# command (an endpoint path, a folded `@base64d` expression) doesn't trip the
# hook.
gh_api_piped_to_base64='(^|[[:space:]|;&(])gh[[:space:]]+api[[:space:]].*\|[[:space:]]*base64([[:space:]]|$)'
gh_api_piped_to_jq='(^|[[:space:]|;&(])gh[[:space:]]+api[[:space:]].*\|[[:space:]]*jq([[:space:]]|$)'

# Match a `git log` listing piped into head, where --max-count does the same
# truncation. Require --oneline ahead of the pipe and allow no stage between
# the two: head counts lines, so the swap holds only while each commit prints
# on one line and nothing downstream has reshaped the listing first.
git_log_piped_to_head='(^|[[:space:]|;&(])git[[:space:]]+log[^|]*--oneline[^|]*\|[[:space:]]*head([[:space:]]|$)'

# Exclude a --graph listing from that match. The graph prefixes continuation
# lines onto the log, so a commit stops occupying exactly one line.
git_log_with_graph='(^|[[:space:]|;&(])git[[:space:]]+log[^|]*--graph'

# Report whether the command holds the given pattern.
command_matches() {
    local pattern="$1"

    printf '%s' "${cmd}" |
        command grep \
            --quiet \
            --extended-regexp \
            -- "${pattern}"
}

guidance=""
if command_matches "${gh_api_piped_to_base64}"; then
    guidance=$'Fold the decode into the jq expression gh runs itself:\n'
    guidance+=$'\n    gh api <endpoint> --jq \'.content | @base64d\'\n'
    guidance+=$'\njq\'s @base64d handles the newlines GitHub wraps the payload in, so no separate un-wrapping stage is needed either.'
elif command_matches "${gh_api_piped_to_jq}"; then
    guidance=$'Hand the filter to gh instead of piping into jq:\n'
    guidance+=$'\n    gh api <endpoint> --jq \'<filter>\'\n'
    guidance+=$'\ngh runs the same jq over the response and --jq takes every filter the standalone jq does.'
elif command_matches "${git_log_piped_to_head}" && ! command_matches "${git_log_with_graph}"; then
    guidance=$'Cap the listing with git log\'s own flag:\n'
    guidance+=$'\n    git log --oneline --max-count=<n>\n'
    guidance+=$'\n--max-count counts commits where head counts lines, so the two agree only while --oneline keeps each commit on one line.'
fi

if [[ -z "${guidance}" ]]; then
    exit 0
fi

reason=$'This pipeline redoes work the upstream command already does through a flag of its own.\n'
reason+=$'\n'"${guidance}"$'\n'
reason+=$'\nThe rewrite also drops the permission prompt: validate_bash_command.sh vets a single command, so a pipeline falls through where the folded form auto-allows.'

command jq \
    --null-input \
    --compact-output \
    --arg reason "${reason}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
