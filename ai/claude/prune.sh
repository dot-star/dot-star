#!/usr/bin/env bash

# Prune Claude sessions.
#
# Scans ~/.claude/projects/*/*.jsonl and removes any session that is one of:
#   - marked done by the model: /tmp/claude/prune_marks/<session-id> exists
#     (written when the user picks the `[x]` close option), or
#   - tagged with a customTitle in the target list (set via /rename), or
#   - a print-mode transcript (one-shot `claude --print` run, e.g. from `cmc`
#     or `ask`), identified by a queue-operation first event.
# A mark is removed along with its session, and any orphan the session left
# running (e.g. a server run from its scratchpad) is killed and logged to
# ~/.claude/prune.log.

set -euo pipefail

printf '🟡 Pruning Claude sessions...'

target_titles=("delete" "del" "d" "tmp")
projects_dir="${HOME}/.claude/projects"
# Keep the marks outside ~/.claude: Claude Code treats .claude as a protected
# path and prompts on every write there, whatever the allow rules say.
marks_dir="/tmp/claude/prune_marks"
# Keep the kills on disk: prune runs in a window that closes right after.
log_file="${HOME}/.claude/prune.log"
# Rotate past this size into a single prune.log.1, so the log never grows unbounded.
log_max_bytes=$((1024 * 1024))

if [[ ! -d "${projects_dir}" ]]; then
    printf '\r\033[K'
    echo "Error: ${projects_dir} does not exist"
    exit 1
fi

rotate_log() {
    local size
    if [[ ! -f "${log_file}" ]]; then
        return 0
    fi

    size="$(wc -c <"${log_file}")"
    if ((size > log_max_bytes)); then
        mv "${log_file}" "${log_file}.1"
    fi
}

rotate_log

is_target_title() {
    local candidate="${1}"
    local target
    for target in "${target_titles[@]}"; do
        if [[ "${candidate}" == "${target}" ]]; then
            return 0
        fi
    done
    return 1
}

# Echo the mark path for a transcript: the session id is the file's basename.
mark_for() {
    local file="${1}"
    local session_id
    session_id="$(basename "${file}" .jsonl)"
    printf '%s/%s' "${marks_dir}" "${session_id}"
}

# True if the model marked the session done via the `[x]` close option.
is_marked_done() {
    local file="${1}"
    [[ -f "$(mark_for "${file}")" ]]
}

# True if the file is a `claude --print` transcript (not a resumable session).
is_print_mode_transcript() {
    local file="${1}"
    local first_type
    first_type="$(
        head -n 1 "${file}" 2>/dev/null |
            \jq -r '.type // empty' 2>/dev/null
    )"
    if [[ "${first_type}" == "queue-operation" ]]; then
        return 0
    fi
    return 1
}

# True if the file is a resumable session, i.e. carries at least one main-thread
# (non-sidechain) event. Subagent transcripts are entirely sidechain, so they
# never match; this counts the same sessions the `claude --resume` picker lists.
is_resumable_session() {
    local file="${1}"
    grep -q '"isSidechain":false' "${file}" 2>/dev/null
}

# Kill orphans a pruned session left running (a server started with a bare `&`
# gets reparented to launchd once its session exits). Require parent 1, so a
# still-live session's children and an editor open on its files survive.
kill_session_processes() {
    local file="${1}"
    local session_id
    local pid
    local parent_pid
    local command_line
    session_id="$(basename "${file}" .jsonl)"
    # Match the id as a path segment, so `claude --resume <id>` never matches.
    while IFS= read -r pid; do
        parent_pid="$(ps -o ppid= -p "${pid}" || true)"
        if [[ "${parent_pid// /}" == "1" ]]; then
            command_line="$(ps -o args= -p "${pid}" || true)"
            # Clear the progress line so the log line starts at column 0.
            printf '\r\033[K🔪 Killing orphan %s of session %s: %s\n' "${pid}" "${session_id}" "${command_line}"
            printf '%s Killing orphan %s of session %s: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${pid}" "${session_id}" "${command_line}" >>"${log_file}"
            kill "${pid}" || true
        fi
    done < <(pgrep -f "/${session_id}/" || true)
}

pruned=0
remaining=0
sessions=0
while IFS= read -r -d '' file; do
    # Pre-filter with grep so jq parses only the last match, not the whole transcript.
    title="$(
        { grep '"type":"custom-title"' "${file}" 2>/dev/null || true; } |
            tail -n 1 |
            \jq -r '.customTitle // empty'
    )"
    if is_marked_done "${file}"; then
        kill_session_processes "${file}"
        rm "${file}" "$(mark_for "${file}")"
        pruned=$((pruned + 1))
    elif is_target_title "${title}"; then
        kill_session_processes "${file}"
        rm "${file}"
        pruned=$((pruned + 1))
    elif is_print_mode_transcript "${file}"; then
        kill_session_processes "${file}"
        rm "${file}"
        pruned=$((pruned + 1))
    else
        remaining=$((remaining + 1))
        if is_resumable_session "${file}"; then
            sessions=$((sessions + 1))
        fi
    fi
done < <(find "${projects_dir}" -type f -name '*.jsonl' -print0)

printf '\r\033[K\033[90m⚪️ Pruning Claude sessions... done (%d pruned, %d remaining, %d sessions)\033[0m\n' "${pruned}" "${remaining}" "${sessions}"
