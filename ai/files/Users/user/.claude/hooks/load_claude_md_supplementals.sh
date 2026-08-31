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

# Assemble the payload via the shared helper, so the statusline's size check
# measures the same bytes this loader emits.
claude_supplemental_assemble
claude_supplemental_emit "${CLAUDE_SUPPLEMENTAL_CONTEXT}" "SessionStart" "${CLAUDE_SUPPLEMENTAL_FILES}"
