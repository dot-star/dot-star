---
name: try
description: Ferry a worktree's working-tree changes into the root (main checkout) so they can be sourced or run live at the installed path (dotfile edits the rest of the system reads from `~/.dot-star`, which symlinks to root). Worktree stays on disk so `/commit` and `wtd` still happen there after `/untry`. TRIGGER when cwd is inside `*/worktrees/*` and the user invokes `/try`, says "try this in root", "test these live", "move it to root for testing", or otherwise signals they want to exercise worktree edits at the root path. SKIP when cwd is the root checkout itself, when the worktree has no working-tree changes (`git status --porcelain` empty), or when a `/try` is already active for this worktree (a `try:wt-source:<name>` entry exists in `git stash list`).
---

# Try

Goal: move this worktree's uncommitted changes into the root checkout so they can be exercised at the path the rest of the machine uses, then return them to the worktree with `/untry`. State is ferried via shared stash entries (worktrees of the same repo share one stash log), no patch files or symlink swaps.

## Preflight

1. Confirm cwd is under `*/worktrees/*`. If not, surface "/try must be run from inside a worktree" and stop.
2. Resolve placeholders:
    - `<root>` from the first entry of `git worktree list`.
    - `<wt>` from `basename "$(git rev-parse --show-toplevel)"`.
3. Confirm the worktree has working-tree changes (staged, unstaged, or untracked): `git status --porcelain` non-empty. If empty, surface "nothing to try in <wt>" and stop. Committed-but-not-working-tree changes are out of scope for v1; if the user has committed and wants to test, suggest `git reset --soft <root-HEAD>` first to bring the diff back into the working tree.
4. Idempotency check: confirm no prior `/try` is active for this worktree:
    - `git stash list --grep="try:wt-source:<wt>" --format="%gd"`
   If non-empty, surface "/try already active for <wt>; run /untry first" and stop.
5. State the plan in one line ("Ferrying <wt>'s working changes to <root>; root edits will be saved aside.") and proceed. The trigger phrase already served as confirmation, do not re-prompt.

## Ferry

1. In the worktree, capture the working state as a stash that doubles as the active-try marker:
    - `git stash push --include-untracked --message "try:wt-source:<wt>"`
2. In the root checkout, save any pre-existing edits aside (only when `cd <root> && git status --porcelain` is non-empty):
    - `cd <root> && git stash push --include-untracked --message "try:root-saved:<wt>"`
3. Apply the worktree's stash in root (apply, do not pop, so the marker stays in the log):
    - Resolve the ref: `wt_source_ref="$(git stash list --grep="try:wt-source:<wt>" --format="%gd" | head -1)"`
    - `cd <root> && git stash apply "${wt_source_ref}"`
4. If the apply reports a conflict, surface the conflicted paths and stop. Do NOT auto-resolve. The worktree's source stash is still in the log, and `try:root-saved:<wt>` (if any) is preserved. Tell the user: resolve the conflict in root (or `cd <root> && git checkout .` to abort the apply), then `/untry` to put things back.

State at end: root has the worktree's working changes applied. Worktree is clean. Stash log holds `try:wt-source:<wt>` and possibly `try:root-saved:<wt>`. Tell the user the changes are live in root, e.g. `source ~/.dot-star/bash/.bash_profile` to reload a shell session.
