#!/usr/bin/env bash
#
# SessionStart hook: inject the always-on ~/.claude/CLAUDE_*.md supplementals
# into session context, in version-sort order, so the base CLAUDE.md rule to
# read them each session is enforced by the harness instead of the model.
# Work-specific docs are NOT here; they live in ai/contexts/ and load via a
# per-repo CLAUDE.local.md @import (uncapped) or the reference-on-mention
# companion hook.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/load_claude_md_supplementals.inc.sh"

claude_dir="${CLAUDE_SUPPLEMENTAL_DIR:-${HOME}/.claude}"

# Concatenate each supplemental under a provenance header. Skip an unreadable
# entry (e.g. a dangling symlink left by a since-moved file) so one stale link
# can't abort the whole load under `set -e`.
context=""
loaded_files=""
while IFS= read -r file; do
    if [ ! -r "${file}" ]; then
        continue
    fi
    context+="===== ${file} ====="$'\n'
    context+="$(cat "${file}")"$'\n\n'
    loaded_files+="${file##*/} "
done < <(ls "${claude_dir}"/CLAUDE_*.md 2>/dev/null | sort --version-sort)

claude_supplemental_emit "${context}" "SessionStart" "${loaded_files% }"
