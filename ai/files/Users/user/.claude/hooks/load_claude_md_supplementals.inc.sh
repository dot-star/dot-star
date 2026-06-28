# Provide shared helpers for the CLAUDE_*.md supplemental loaders (the
# SessionStart always-on loader and the UserPromptSubmit reference-on-mention
# companion). Source this; do not execute it. Parse the `claude-mention` marker
# and emit additionalContext, warning loudly when the payload nears the cap.

# Warn before the payload breaches the documented 10,000-character cap on hook
# additionalContext (see https://code.claude.com/docs/en/hooks.md#size-limits).
# Past the cap the string is offloaded to a file and replaced with a short
# preview, silently dropping the rest. Keep this below the cap so the banner
# surfaces while content is still at risk rather than already gone.
CLAUDE_SUPPLEMENTAL_WARN_BYTES=9000

# Echo a context file's `claude-mention` keywords (the text between
# "claude-mention:" and "-->"), or nothing when the file carries no marker.
# List keywords one per line inside a single marker block for readable diffs:
#     <!-- claude-mention:
#         deploy
#         rollback
#         release
#     -->
# Accept a single-line too:
#     <!-- claude-mention: deploy, rollback -->
# Emit one comma-separated string either way; splitting and matching is the
# caller's job.
claude_supplemental_mention_keyword() {
    local file="$1"

    awk '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        function emit(s,   t) {
            t = trim(s)
            if (t != "") {
                out = (out == "" ? t : out "," t)
            }
        }

        # Collect keyword lines until the block closes with "-->".
        collecting {
            if (index($0, "-->") > 0) {
                line = $0
                sub(/-->.*/, "", line)
                emit(line)
                collecting = 0
            } else {
                emit($0)
            }
            next
        }

        # Open a marker; the keywords are inline (single-line) or below (block).
        match($0, /<!--[ \t]*claude-mention:/) {
            rest = substr($0, RSTART)
            sub(/<!--[ \t]*claude-mention:/, "", rest)
            if (index(rest, "-->") > 0) {
                sub(/-->.*/, "", rest)
                emit(rest)
            } else {
                emit(rest)
                collecting = 1
            }
        }

        END { print out }
    ' "${file}"
}

# Emit <context> as additionalContext for the <event> hook, prepending a loud
# banner that names the at-risk <files> when the payload would breach the cap.
# No-op on empty context.
claude_supplemental_emit() {
    local context="$1"
    local event="$2"
    local files="$3"
    local context_bytes

    if [ -z "${context}" ]; then
        return 0
    fi

    context_bytes=$(printf '%s' "${context}" |
        wc -c |
        awk '{print $1}')
    if [ "${context_bytes}" -gt "${CLAUDE_SUPPLEMENTAL_WARN_BYTES}" ]; then
        local context_kb
        local warn_kb
        local banner
        context_kb=$(awk "BEGIN { printf \"%.1f\", ${context_bytes} / 1024 }")
        warn_kb=$(awk "BEGIN { printf \"%.1f\", ${CLAUDE_SUPPLEMENTAL_WARN_BYTES} / 1024 }")
        banner="⚠️ dot-star supplemental context is ${context_kb}KB, over the ${warn_kb}KB warn threshold. The harness persists oversize hook output and injects only a ~2KB preview, so anything past that is silently dropped from context. Scope or trim these auto-loaded files: ${files}."
        context="${banner}"$'\n\n'"${context}"
    fi

    command jq \
        --null-input \
        --compact-output \
        --arg context "${context}" \
        --arg event "${event}" \
        '{hookSpecificOutput: {hookEventName: $event, additionalContext: $context}}'
}
