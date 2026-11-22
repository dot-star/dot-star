#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): sync a file's executable bit to whether it's a
# standalone runnable script. A script meant to run declares an interpreter with a
# shebang AND is not a dot-prefixed fragment; those get +x. Sourced fragments
# (`.aliases.sh`) and data files get -x, so a sourced `.timer.sh` that carries a
# shebang for editor hints never drifts to executable on edit.

set -u

# Detect a shebang from a file's first two bytes.
has_shebang() {
    local file="$1"
    local prefix

    prefix=$(head -c2 "${file}")
    if [ "${prefix}" = '#!' ]; then
        return 0
    fi

    return 1
}

# Detect a dot-prefixed fragment (`.aliases.sh`), sourced rather than executed.
is_sourced_fragment() {
    local file="$1"
    local base

    base=$(basename "${file}")
    case "${base}" in
    .*)
        return 0
        ;;
    esac

    return 1
}

file=$(command jq --raw-output '.tool_response.filePath // .tool_input.file_path // empty')
# Bail unless it's a real, non-symlink file. chmod follows a symlink to its target.
if [ -z "${file}" ] || [ ! -f "${file}" ] || [ -L "${file}" ]; then
    exit 0
fi

was_executable=false
if [ -x "${file}" ]; then
    was_executable=true
fi

# Grant +x only to a standalone runnable script: a shebang declares its interpreter
# and a dot-prefix would mark it sourced. Fragments and data files get -x.
if has_shebang "${file}" && ! is_sourced_fragment "${file}"; then
    chmod +x "${file}"
else
    chmod -x "${file}"
fi

is_executable=false
new_mode="100644"
if [ -x "${file}" ]; then
    is_executable=true
    new_mode="100755"
fi

if [ "${was_executable}" = "${is_executable}" ]; then
    exit 0
fi

# Report a flip away from the mode git tracks, so it lands as its own commit
# instead of riding silently inside whatever change touched the file.
tracked_mode=$(
    git \
        -C "$(dirname "${file}")" \
        ls-files \
        --stage \
        -- "$(basename "${file}")" 2>/dev/null |
        cut -d ' ' -f 1
)
if [ -z "${tracked_mode}" ] || [ "${tracked_mode}" = "${new_mode}" ]; then
    exit 0
fi

context="enforce_executable_bit.sh changed the mode of ${file} to ${new_mode}; git tracks it as ${tracked_mode},"
context+=" so the next commit touching it carries a mode change."
context+=" If the file is run directly, add a shebang."
command jq \
    --null-input \
    --compact-output \
    --arg context "${context}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
