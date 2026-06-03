#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): make a written `*.sh` file executable.

set -u

file=$(command jq --raw-output '.tool_response.filePath // .tool_input.file_path')
case "${file}" in
*.sh)
    chmod +x "${file}"
    ;;
esac
