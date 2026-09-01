#!/usr/bin/env bash
# PreToolUse hook: auto-allow `git log` (with or without args) and a read-only
# `gh api` fetch. Anything else falls through to the normal permission flow.

set -u

# Hold the tokens the last `tokenize` call produced.
tokens=()

# Fail on any shell metacharacter that breaks the literal-string assumption:
# command chaining (; & | newline), redirection (< >), substitution ($ `),
# quoting (" ' \), brace expansion ({ }), and tab as IFS-only separator.
is_metacharacter_free() {
    case "${1}" in
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
        return 1
        ;;
    esac

    return 0
}

# Split a command into `tokens`, treating "..." and '...' as grouping alone.
# Fail on any character that could mean more than the text it spells:
#
#   - Reject substitution ($ `), escaping (\), and tab or newline as a
#     separator, quoted or not.
#   - Reject chaining (; & |), redirection (< >), grouping ({ } ( )), and
#     globbing (* ? [) outside quotes, where each still carries its shell
#     meaning. Note the glob: it expands off the filesystem, so one token
#     here would otherwise reach the command as several words, one of them
#     shaped like a flag.
#   - Reject an unbalanced quote, which leaves the split ambiguous.
tokenize() {
    local text="${1}"
    local quote=""
    local current=""
    local started=0
    local index=0
    local char

    tokens=()
    while [[ "${index}" -lt "${#text}" ]]; do
        char="${text:index:1}"
        index=$((index + 1))

        case "${char}" in
        '`' | '$' | '\' | $'\n' | $'\t')
            return 1
            ;;
        esac

        if [[ -n "${quote}" ]]; then
            if [[ "${char}" == "${quote}" ]]; then
                quote=""
            else
                current+="${char}"
            fi
            continue
        fi

        case "${char}" in
        '"' | "'")
            quote="${char}"
            started=1
            ;;
        ';' | '&' | '|' | '<' | '>' | '{' | '}' | '(' | ')' | '*' | '?' | '[')
            return 1
            ;;
        ' ')
            if [[ "${started}" -eq 1 ]]; then
                tokens+=("${current}")
                current=""
                started=0
            fi
            ;;
        *)
            current+="${char}"
            started=1
            ;;
        esac
    done

    if [[ -n "${quote}" ]]; then
        return 1
    fi

    if [[ "${started}" -eq 1 ]]; then
        tokens+=("${current}")
    fi

    return 0
}

# Accept one `gh api <endpoint>` carrying no flag beyond --paginate and --jq,
# the two that cannot turn the request into a write. Reject every other flag
# rather than classify it: -X, -F, -f and --input already write, and gh keeps
# adding flags, so an unrecognized one prompts instead of riding in free.
#
# The caller dispatches on a literal `gh api ` prefix, so tokens 0 and 1 are
# always `gh` and `api`; the scan starts past them.
is_gh_api_read() {
    local index=2
    local endpoints=0
    local token

    if ! tokenize "${1}"; then
        return 1
    fi

    while [[ "${index}" -lt "${#tokens[@]}" ]]; do
        token="${tokens[index]}"
        index=$((index + 1))

        case "${token}" in
        # Accept the flag and move on. Neither spends a following token.
        "--paginate" | "--jq="*) ;;
        "--jq")
            # Step over the jq expression. It is data for jq, never a gh flag.
            if [[ "${index}" -ge "${#tokens[@]}" ]]; then
                return 1
            fi
            index=$((index + 1))
            ;;
        -*)
            return 1
            ;;
        *)
            endpoints=$((endpoints + 1))
            ;;
        esac
    done

    if [[ "${endpoints}" -ne 1 ]]; then
        return 1
    fi

    return 0
}

cmd=$(command jq --raw-output '.tool_input.command')

# Safe-list: each entry covers the bare form and the args form; nothing else.
reason=""
case "${cmd}" in
"git log" | \
    "git log "*)
    if ! is_metacharacter_free "${cmd}"; then
        exit 0
    fi
    reason="read-only git log"
    ;;
"gh api "*)
    if ! is_gh_api_read "${cmd}"; then
        exit 0
    fi
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
