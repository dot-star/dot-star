# Helpers for the hooks that close a claude session once it's marked for prune:
# find the session's claude process, leave its full-screen Space and tell
# claude_run (ai/.aliases.sh) the coming SIGTERM was asked for. Source this;
# don't execute it.

prune_marks_dir="/tmp/claude/prune_marks"
# Hold one file per session whose turn is still running, so a bare `x` sent
# mid-turn waits for that turn's work instead of killing it.
open_turns_dir="/tmp/claude/open_turns"
# Read the session's state word (busy, decision, ready) from announce_window_state.py.
session_state_dir="/tmp/claude-state-hook"
# Keep the close log outside the transcript, since prune.sh deletes that.
close_log="${HOME}/.claude/session_close.jsonl"
# Rotate past this size into a single .1 file, so the log never grows unbounded.
close_log_max_bytes=$((1024 * 1024))
# Read only the transcript's tail, since a long session runs to megabytes.
close_log_transcript_lines=400

# Print the nearest `claude` ancestor's pid, or nothing when there is none.
# Walk up from the parent rather than trusting it, since a hook may run under a
# `sh -c` wrapper. Return nonzero when a lookup fails, since a command
# substitution drops `set -e` and would otherwise end the walk quietly.
find_claude_pid() {
    local pid="${PPID}"
    local comm

    while [[ "${pid}" -gt 1 ]]; do
        comm=$(ps -o comm= -p "${pid}") || return 1
        if [[ "${comm##*/}" == "claude" ]]; then
            echo "${pid}"
            return 0
        fi

        pid=$(ps -o ppid= -p "${pid}" | tr -d ' ') || return 1
    done
}

# Print whether the session has a turn open ("open") or none ("none").
describe_turn() {
    local session_id="$1"

    if [[ -e "${open_turns_dir}/${session_id}" ]]; then
        echo "open"
    else
        echo "none"
    fi
}

# Touch the marker claude_run exports, since SIGTERM restores the terminal just
# as Ctrl+D does but exits 143.
mark_close_requested() {
    if [[ -n "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER:-}" ]]; then
        touch -- "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}"
    fi
}

# Append one JSON line per close: what closed it, when the mark landed, the
# tree's uncommitted paths and the last exchange. A dirty tree beside a reply
# still waiting on the user marks a close that came too early.
log_session_close() {
    local trigger="$1"
    local session_id="$2"
    local cwd="$3"
    local transcript_path="$4"
    local turn="$5"

    # Close the session anyway; a broken log line costs less than a stuck one.
    if ! write_session_close_entry "${trigger}" "${session_id}" "${cwd}" "${transcript_path}" "${turn}" 2>/dev/null; then
        true
    fi
}

write_session_close_entry() {
    local trigger="$1"
    local session_id="$2"
    local cwd="$3"
    local transcript_path="$4"
    local turn="$5"
    local mark="${prune_marks_dir}/${session_id}"
    local mark_written=""
    local state=""
    local uncommitted=""
    local filter
    local size

    if [[ -e "${mark}" ]]; then
        mark_written=$(date -r "${mark}" '+%Y-%m-%dT%H:%M:%S')
    fi

    # Record the turn and state words too, since an open turn or a busy state marks a close that cut work short.
    if [[ -f "${session_state_dir}/${session_id}.state" ]]; then
        state=$(<"${session_state_dir}/${session_id}.state")
    fi

    if [[ -d "${cwd}" ]]; then
        if ! uncommitted=$(git -C "${cwd}" status --porcelain 2>/dev/null); then
            uncommitted=""
        fi
    fi

    if [[ -f "${close_log}" ]]; then
        size=$(wc -c <"${close_log}")
        if ((size > close_log_max_bytes)); then
            mv -- "${close_log}" "${close_log}.1"
        fi
    fi

    filter=$(
        cat <<'JQ'
# Pull a turn's typed text, skipping tool calls and their results.
def text_of: .message.content
    | if type == "string" then . else map(select(.type == "text") | .text) | join("\n") end;

(split("\n") | map(fromjson? // empty)) as $events
| {
    time: $time,
    trigger: $trigger,
    session_id: $session_id,
    cwd: $cwd,
    mark_written: $mark_written,
    turn: $turn,
    state: $state,
    uncommitted: ($uncommitted | split("\n") | map(select(. != ""))),
    last_prompt: ([$events[] | select(.type == "user") | text_of | select(. != "")] | last // "" | .[:300]),
    last_reply_tail: ([$events[] | select(.type == "assistant") | text_of | select(. != "")] | last // "" | .[-600:])
}
JQ
    )

    # Stream the transcript through stdin, since its tail outgrows an argument.
    mkdir --parents -- "$(dirname -- "${close_log}")"
    print_transcript_tail "${transcript_path}" |
        command jq \
            --raw-input \
            --slurp \
            --compact-output \
            --arg "time" "$(date '+%Y-%m-%dT%H:%M:%S')" \
            --arg "trigger" "${trigger}" \
            --arg "session_id" "${session_id}" \
            --arg "cwd" "${cwd}" \
            --arg "mark_written" "${mark_written}" \
            --arg "turn" "${turn}" \
            --arg "state" "${state}" \
            --arg "uncommitted" "${uncommitted}" \
            "${filter}" \
            >>"${close_log}"
}

# Print the transcript's last lines, or nothing when it's gone.
print_transcript_tail() {
    local transcript_path="$1"

    if [[ -f "${transcript_path}" ]]; then
        tail --lines "${close_log_transcript_lines}" -- "${transcript_path}"
    fi
}

# Leave the full-screen Space now rather than once the window closes, since the
# page is done; claude_run skips its own follow after a requested close. Pass
# the session id so the hop skips once focus has moved on to another window.
# Pass the claude pid when already known, so the hop skips its own ancestor walk.
leave_full_screen_space() {
    local session_id="$1"
    local claude_pid="$2"

    if ! "${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh" "now" "${session_id}" "${claude_pid}"; then
        # Close the session anyway; the script already printed why the hop failed.
        true
    fi
}
