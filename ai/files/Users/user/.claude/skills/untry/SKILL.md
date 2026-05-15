---
name: untry
description: Reverse a `/try`: capture root's now-possibly-tweaked tested state and put it back into the worktree, restoring root's pre-`/try` edits if any were saved aside. After `/untry` the worktree holds the (possibly tweaked) tested state and root looks the way it did before `/try`, so `/commit` and `wtd` happen in the worktree as usual. TRIGGER when cwd is inside `*/worktrees/*` and the user invokes `/untry`, says "put it back", "move it back to the worktree", "done testing", or otherwise signals they want to undo a `/try`. SKIP when no `/try` is active for this worktree (no `try:wt-source:<name>` entry in `git stash list`), or when the worktree has unrelated uncommitted edits that would conflict with the tested state coming back.
---

# Untry

Goal: undo a `/try`: pull the (possibly tweaked) tested state back from root into the worktree, then pop root's saved edits so root looks the way it did before `/try`. Worktree ends up with what should be committed; root ends up clean (or back to its pre-`/try` edits).

## Preflight

1. Confirm cwd is under `*/worktrees/*`. If not, surface "/untry must be run from inside the worktree the /try originated from" and stop.
2. Resolve placeholders: `<root>` and `<wt>` as in `/try`, plus `<wt-path>` from `git rev-parse --show-toplevel` (the full path of the worktree, used to cd back after the root-side stash push).
3. Confirm a `/try` is active for this worktree:
    - `git stash list --grep="try:wt-source:<wt>" --format="%gd"`
   If empty, surface "no /try active for <wt>" and stop.
4. Confirm the worktree is clean (`git status --porcelain` empty). It should be, because `/try` emptied it. If dirty, surface the dirty paths and stop; the user must reconcile (commit, stash, or discard) before the tested state can be reapplied here without conflict.
5. State the plan ("Returning tested state from <root> to <wt>; restoring root's saved edits.") and proceed.

## Ferry back

1. In the root checkout, capture the current (possibly tweaked) state into a stash:
    - `cd <root> && git stash push --include-untracked --message "try:wt-final:<wt>"`
   If `cd <root> && git status --porcelain` was empty (user reverted everything during testing), skip this step; nothing to bring back. Note this case in the report so the user knows the worktree will end up empty.
2. In the worktree, apply the captured state (only if step 1 produced a stash):
    - `wt_final_ref="$(git stash list --grep="try:wt-final:<wt>" --format="%gd" | head -1)"`
    - `cd <wt-path> && git stash apply "${wt_final_ref}"`
   The explicit `cd <wt-path>` is load-bearing: step 1 left cwd in `<root>`, so a bare `git stash apply` chained from there lands the tested state in root, not the worktree, and you end up doing a fixup stash-push-pop to move it back. On conflict (rare; worktree was clean), surface paths and stop without dropping any stash.
3. Drop the carrier stashes (only those that exist):
    - `git stash drop "${wt_final_ref}"` (if step 1 produced one)
    - `wt_source_ref="$(git stash list --grep="try:wt-source:<wt>" --format="%gd" | head -1)"`
    - `git stash drop "${wt_source_ref}"`
4. In the root checkout, restore the pre-`/try` edits if they were saved:
    - `root_saved_ref="$(git stash list --grep="try:root-saved:<wt>" --format="%gd" | head -1)"`
    - If non-empty: `cd <root> && git stash pop "${root_saved_ref}"`

State at end: worktree has the tested state (tweaks preserved). Root is back to its pre-`/try` state. No `try:*:<wt>` stashes remain. The user can now `/commit` in the worktree as usual.
