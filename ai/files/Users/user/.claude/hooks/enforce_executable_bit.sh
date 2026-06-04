#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): sync a file's executable bit to whether it has a
# shebang. Scripts meant to run (`#!...`) get +x; sourced fragments and data files
# get -x, so a sourced `.aliases.sh` never drifts back to executable on edit.

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

file=$(command jq --raw-output '.tool_response.filePath // .tool_input.file_path // empty')
# Bail unless it's a real, non-symlink file. chmod follows a symlink to its target.
if [ -z "${file}" ] || [ ! -f "${file}" ] || [ -L "${file}" ]; then
    exit 0
fi

if has_shebang "${file}"; then
    chmod +x "${file}"
else
    chmod -x "${file}"
fi
