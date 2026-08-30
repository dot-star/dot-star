#!/usr/bin/env bash
# PreToolUse hook: auto-allow `git log` (with or without args) and a bare
# `gh api <endpoint>` read. Anything else, or any shell metacharacter, falls
# through to the normal permission flow.

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
reason=""
case "${cmd}" in
"git log" | \
    "git log "*)
    reason="read-only git log"
    ;;
"gh api "*)
    # Require a lone endpoint. Any flag can turn the request into a write
    # (-X, -F, -f, --input), and whitelisting the read-only ones would grant
    # every flag gh adds later, so anything past the endpoint falls through.
    endpoint="${cmd#gh api }"
    case "${endpoint}" in
    "" | -* | *" "*)
        exit 0
        ;;
    esac
    reason="read-only gh api endpoint fetch"
    ;;
*)
    exit 0
    ;;
esac

command jq \
    --null-input \
    --compact-output \
    --arg reason "${reason}" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$reason}}'
