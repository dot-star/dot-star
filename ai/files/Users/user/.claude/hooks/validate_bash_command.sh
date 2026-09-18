#!/usr/bin/env bash
# PreToolUse hook: decide the prompt for the commands a permission rule cannot
# describe. Auto-allow `git log` (with or without args), a read-only `gh api`
# fetch, a `gh` view/list/diff read, and the one fold that needs no
# confirmation; force a prompt on every other `git commit`. Anything else
# falls through to the normal permission flow.
#
# The `git commit` gate lives here rather than in an `ask` rule because the
# rule language has no negation and an ask rule outranks both allow rules and
# this hook, so a single `Bash(git commit:*)` entry would prompt for the fold
# too.

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

# Accept a `gh` subcommand that only reads GitHub, vetted by verb pair; every
# `gh search` verb reads. Reject the flags that reach past the terminal:
# `--web` opens a browser and `--watch` blocks until the checks settle.
is_gh_read_subcommand() {
    local pair
    local token

    if ! tokenize "${1}"; then
        return 1
    fi

    for token in "${tokens[@]}"; do
        case "${token}" in
        "-w" | "--web" | "--web="* | "--watch" | "--watch="*)
            return 1
            ;;
        esac
    done

    if [[ "${#tokens[@]}" -ge 2 && "${tokens[1]}" == "search" ]]; then
        return 0
    elif [[ "${#tokens[@]}" -lt 3 ]]; then
        return 1
    fi

    pair="${tokens[1]} ${tokens[2]}"
    case "${pair}" in
    "issue list" | \
        "issue status" | \
        "issue view" | \
        "pr checks" | \
        "pr diff" | \
        "pr list" | \
        "pr status" | \
        "pr view" | \
        "release list" | \
        "release view" | \
        "repo list" | \
        "repo view" | \
        "run list" | \
        "run view" | \
        "workflow list" | \
        "workflow view")
        return 0
        ;;
    esac

    return 1
}

# Report whether one command only reads, so the prompt it would raise carries
# no decision to make. Each entry covers the bare form and the args form.
is_read_only_command() {
    case "${1}" in
    "git log" | \
        "git log "*)
        is_metacharacter_free "${1}"
        ;;
    "gh api "*)
        is_gh_api_read "${1}"
        ;;
    "gh "*)
        is_gh_read_subcommand "${1}"
        ;;
    *)
        return 1
        ;;
    esac
}

# Report whether `git commit` runs as a command here: at the start of the text
# or after a character that opens a new one. Ignore the phrase inside an
# argument (`grep "git commit"`), which commits nothing and needs no prompt.
runs_git_commit() {
    local opener=$'(^|[;&|(`\n])'

    [[ "${1}" =~ ${opener}[[:space:]]*git[[:space:]]+commit([[:space:]]|$) ]]
}

# Emit a permission decision and leave. Staying silent instead hands the
# command to the normal permission flow.
emit_decision() {
    command jq \
        --null-input \
        --compact-output \
        --arg decision "${1}" \
        --arg reason "${2}" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$decision,permissionDecisionReason:$reason}}'

    exit 0
}

cmd=$(command jq --raw-output '.tool_input.command')

# Wave the fold through: `--no-edit` writes no new subject and opens no editor,
# so the amend leaves nothing to confirm. Match the exact text, since any extra
# flag or pipeline stage is a different command.
if [[ "${cmd}" == "git commit --amend --no-edit" ]]; then
    emit_decision allow "fold the staged change into HEAD, subject untouched"
elif runs_git_commit "${cmd}"; then
    emit_decision ask "git commit writes history; confirm the command first"
fi

# Wave a read through; anything off the safe-list falls through to the normal
# permission flow.
if ! is_read_only_command "${cmd}"; then
    exit 0
fi

emit_decision allow "the command only reads"
