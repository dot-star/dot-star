#!/usr/bin/env bash
#
# statusLine hook: prints adjacent bracketed segments of the form
#   [<context-size>][<worktree-name>][<title> - <objective>]
# Each bracket is optional. The second bracket renders whichever of title /
# objective is present; both together are joined with " - ".
#
# Sources:
#   - context:   prompt tokens of the last main-chain assistant turn in the
#                transcript, flagged ⚠️ past CONTEXT_WARN_TOKENS and 🚨 past
#                CONTEXT_ALERT_TOKENS
#   - worktree:  session-scoped marker (worktree_marker.sh), else cwd inspection
#   - title:     most recent {"type":"custom-title", ...} in the transcript
#                (written by /rename)
#   - objective: session-scoped marker /tmp/claude/<sid>/objective when present
#                (caveman summary written by the assistant on the first user
#                message), else the first plain user prompt in the transcript

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

cyan=$'\033[36m'
yellow=$'\033[33m'
bold_red=$'\033[1;31m'
reset=$'\033[0m'

OBJECTIVE_MAX_CHARS=60
OBJECTIVE_MAX_WORDS=6

# Warn (⚠️) on the context segment past this many tokens, then escalate to an
# alert (🚨) past the higher mark. By tier, the segment renders:
#   [63k]           below warn
#   [⚠️210k/300k]    warn
#   [🚨312k/300k]    alert
CONTEXT_WARN_TOKENS=200000
CONTEXT_ALERT_TOKENS=300000

flatten() {
    local s="$1"
    s="${s//$'\n'/ }"
    s="${s//$'\r'/ }"
    printf '%s' "${s}"
}

shrink() {
    local s
    s="$(flatten "$1")"
    local max_chars="$2"
    local max_words="$3"

    local words
    read -r -a words <<<"${s}"
    local original_count="${#words[@]}"

    # Drop whole trailing words until within the word cap and within the char
    # cap (reserving one char for the ellipsis appended below).
    while [ "${#words[@]}" -gt "${max_words}" ] ||
        { [ "${#words[@]}" -gt 1 ] && [ "${#s}" -gt "$((max_chars - 1))" ]; }; do
        unset 'words[$((${#words[@]} - 1))]'
        s="${words[*]}"
    done

    if [ "${#words[@]}" -lt "${original_count}" ]; then
        # Words were dropped; signal the truncation.
        s="${s}…"
    elif [ "${#s}" -gt "${max_chars}" ]; then
        # A single word still overflows the char cap; hard-cut it.
        s="${s:0:max_chars-1}…"
    fi

    printf '%s' "${s}"
}

data=$(cat)

worktree_name=""

sid_dir=$(claude_session_dir "$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')")
marker="${sid_dir}/worktree"
if [ -n "${sid_dir}" ] && [ -f "${marker}" ]; then
    path=$(head -n 1 "${marker}")
    if [ -d "${path}" ]; then
        worktree_name="${path##*/}"
    fi
fi

if [ -z "${worktree_name}" ]; then
    cwd=$(printf '%s' "${data}" | command jq --raw-output '.cwd // .workspace.current_dir // empty')
    if [ -n "${cwd}" ]; then
        gitdir=$(cd "${cwd}" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null || true)
        case "${gitdir}" in
        */worktrees/*)
            worktree_name="${gitdir##*/worktrees/}"
            worktree_name="${worktree_name%%/*}"
            ;;
        esac
    fi
fi

title=""
objective=""

obj_marker="${sid_dir}/objective"
if [ -n "${sid_dir}" ] && [ -f "${obj_marker}" ]; then
    objective=$(head -n 1 "${obj_marker}")
fi

transcript=$(printf '%s' "${data}" | command jq --raw-output '.transcript_path // empty')
if [ -n "${transcript}" ] && [ -f "${transcript}" ]; then
    title=$(grep --fixed-strings '"type":"custom-title"' "${transcript}" |
        tail -n 1 |
        command jq --raw-output '.customTitle // empty' \
            2>/dev/null || true)

    if [ -z "${objective}" ]; then
        # First plain user prompt: skip sub-agent turns, tool results (array
        # content), and slash-command / system-tag messages.
        objective=$(grep --fixed-strings '"type":"user"' "${transcript}" |
            head -n 30 |
            command jq --raw-output 'select(.isSidechain == false
                                              and (.message.content | type) == "string"
                                              and (.message.content | startswith("<") | not)
                                              and (.message.content | startswith("/") | not))
                                       | .message.content' \
                2>/dev/null |
            head -n 1 ||
            true)
    fi
fi

title=$(flatten "${title}")
objective=$(shrink "${objective}" "${OBJECTIVE_MAX_CHARS}" "${OBJECTIVE_MAX_WORDS}")
if [ -n "${title}" ] && [ "${title}" = "${objective}" ]; then
    objective=""
fi

# Read the current context size from the last main-chain assistant turn's prompt
# tokens (input + cache creation + cache read). Reverse the transcript so the
# newest turn lands first, then stop at the first match.
context_tokens=""
if [ -n "${transcript}" ] && [ -f "${transcript}" ]; then
    context_tokens=$({ tail -r "${transcript}" 2>/dev/null || tac "${transcript}"; } |
        command jq --raw-output 'select(.isSidechain == false and .message.usage != null)
                                   | .message.usage
                                   | (.input_tokens // 0)
                                       + (.cache_creation_input_tokens // 0)
                                       + (.cache_read_input_tokens // 0)' \
            2>/dev/null |
        head -n 1 ||
        true)
fi

# Format the context size, bare until it needs attention: below the warn mark it
# shows just the count in the bar's own gray, then escalates to a ⚠️ and 🚨
# budget against the alert ceiling.
context_segment=""
if [ -n "${context_tokens}" ] && [ "${context_tokens}" -gt 0 ] 2>/dev/null; then
    context_k=$((context_tokens / 1000))
    context_limit="/$((CONTEXT_ALERT_TOKENS / 1000))k"
    if [ "${context_tokens}" -ge "${CONTEXT_ALERT_TOKENS}" ]; then
        context_color="${bold_red}"
        context_reset="${reset}"
        context_marker="🚨"
    elif [ "${context_tokens}" -ge "${CONTEXT_WARN_TOKENS}" ]; then
        context_color="${yellow}"
        context_reset="${reset}"
        context_marker="⚠️"
    else
        context_color=""
        context_reset=""
        context_marker=""
        context_limit=""
    fi
    context_segment="[${context_color}${context_marker}${context_k}k${context_limit}${context_reset}]"
fi

out="${context_segment}"
if [ -n "${worktree_name}" ]; then
    out+="[${cyan}${worktree_name}${reset}]"
fi

if [ -n "${title}" ] && [ -n "${objective}" ]; then
    out+="[${title} - ${objective}]"
elif [ -n "${title}" ]; then
    out+="[${title}]"
elif [ -n "${objective}" ]; then
    out+="[${objective}]"
fi

if [ -n "${out}" ]; then
    printf '%s\n' "${out}"
fi
