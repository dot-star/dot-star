#!/usr/bin/env bash
#
# statusLine hook: prints adjacent bracketed segments of the form
#   [worktree: <name>][<title> - <objective>]
# Each bracket is optional. The second bracket renders whichever of title /
# objective is present; both together are joined with " - ".
#
# Sources:
#   - worktree:  session-scoped marker (worktree_marker.sh), else cwd inspection
#   - title:     most recent {"type":"custom-title", ...} in the transcript
#                (written by /rename)
#   - objective: session-scoped marker /tmp/claude/<sid>/objective when present
#                (caveman summary written by the assistant on the first user
#                message), else the first plain user prompt in the transcript

set -euo pipefail

cyan=$'\033[36m'
reset=$'\033[0m'

OBJECTIVE_MAX_CHARS=60
OBJECTIVE_MAX_WORDS=6

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

wt_name=""

sid=$(printf '%s' "${data}" | command jq --raw-output '.session_id // empty')
sid="${sid//[^a-zA-Z0-9-]/}"
marker="/tmp/claude/${sid}/worktree"
if [ -n "${sid}" ] && [ -f "${marker}" ]; then
    path=$(head -n 1 "${marker}")
    if [ -d "${path}" ]; then
        wt_name="${path##*/}"
    fi
fi

if [ -z "${wt_name}" ]; then
    cwd=$(printf '%s' "${data}" | command jq --raw-output '.cwd // .workspace.current_dir // empty')
    if [ -n "${cwd}" ]; then
        gitdir=$(cd "${cwd}" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null || true)
        case "${gitdir}" in
        */worktrees/*)
            wt_name="${gitdir##*/worktrees/}"
            wt_name="${wt_name%%/*}"
            ;;
        esac
    fi
fi

title=""
objective=""

obj_marker="/tmp/claude/${sid}/objective"
if [ -n "${sid}" ] && [ -f "${obj_marker}" ]; then
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

out=""
if [ -n "${wt_name}" ]; then
    out+="[worktree: ${cyan}${wt_name}${reset}]"
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
