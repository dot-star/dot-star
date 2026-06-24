# Resolve the session-scoped tmp dir from a raw hook session id. Source this; do
# not execute it. Centralize the abbreviation so every consumer (SessionStart
# creator, statusline, worktree marker, supplemental loader) builds the same path.

# Echo /tmp/claude/<short-id> for a raw session id, or nothing when it is empty.
# Sanitize to [A-Za-z0-9-], then abbreviate to 7 chars (git-short style: the
# leading hex of the uuid, dashless since the first dash sits at index 8).
claude_session_dir() {
    local sid="${1//[^a-zA-Z0-9-]/}"
    sid="${sid:0:7}"

    if [ -z "${sid}" ]; then
        return 0
    fi

    printf '/tmp/claude/%s' "${sid}"
}
