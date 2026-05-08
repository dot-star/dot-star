#!/usr/bin/env bash
# PreToolUse hook: auto-allow `git log` (with or without args). Anything else,
# or any shell metacharacter, falls through to the normal permission flow.

set -u

cmd=$(command jq --raw-output '.tool_input.command')

# Reject any shell metacharacter that breaks the literal-string assumption:
# command chaining (; & | newline), redirection (< >), substitution ($ `),
# quoting (" ' \), brace expansion ({ }), and tab as IFS-only separator.
case "${cmd}" in
*'`'* | \
    *'$'* | \
    *'|'* | \
    *'>'* | \
    *'<'* | \
    *';'* | \
    *'&'* | \
    *'{'* | \
    *'}'* | \
    *'"'* | \
    *"'"* | \
    *'\'* | \
    *$'\n'* | \
    *$'\t'*)
    exit 0
    ;;
esac

# Safe-list: each entry covers the bare form and the args form; nothing else.
case "${cmd}" in
"git log" | \
    "git log "*) ;;
*) exit 0 ;;
esac

printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"read-only git log"}}'
