---
name: worktree-done
description: Land a worktree's commits back into the default branch in the main checkout and remove the worktree. TRIGGER when cwd is inside `*/worktrees/*` and the user signals work is done (e.g. "ship it", "land it", "merge it back", "clean up the worktree", "wrap this up"). SKIP when not in a worktree, when there are uncommitted changes the user has not addressed, or when the user is mid-task.
---

# Worktree done

Goal: collapse "merge worktree branch back, remove worktree, delete branch" into one action, run from inside the worktree.

## Preflight

1. Confirm cwd is under `*/worktrees/*`.
2. Resolve placeholders: `<branch>` from `git symbolic-ref --short HEAD`; `<main>` from the first entry of `git worktree list`; `<default>` from the main checkout's HEAD branch (or the project's `git_default_branch` helper).
3. Confirm working tree is clean (`git status --porcelain` empty); if not, surface the dirty paths and stop. Carve-out: an untracked empty `.claude/settings.local.json` (auto-created by Claude Code, not user work) does not count as dirty. To check, expand `?? .claude/` with `git status --porcelain --untracked-files=all` and treat the gate as satisfied when the only untracked entry is `.claude/settings.local.json` and that file is zero bytes. When the file exists and is non-empty, `Read` it and display its contents inline as part of the dirty-tree report so the user can see the accumulated permissions before deciding (typically: delete the file if the entries are one-off).
4. Confirm the branch has commits ahead of `<default>` (`git log <default>..HEAD --oneline` non-empty); if not, there is nothing to land.
5. State in one line what is about to happen ("Landing branch X from worktree Y into Z and removing the worktree."), then proceed. The trigger phrase already served as confirmation, do not re-prompt.

## Land

Two paths, depending on how the worktree was created:

- **EnterWorktree-managed (this session created it via the `EnterWorktree` tool):** do the merge manually so `ExitWorktree`'s session tracking stays in sync.
    1. Rebase the branch onto `<default>` from inside the worktree: `git rebase <default>`. This is a no-op when already up to date and avoids a noisy FF failure when `<default>` has advanced. Bail if the rebase itself errors (e.g. conflict).
    2. Fast-forward in the main checkout, gated on a clean ancestry precheck so the FF never errors out with red exit 128: `git -C <main> checkout <default> && git -C <main> merge-base --is-ancestor <default> <branch> && git -C <main> merge --ff-only <branch>`. Use `git -C <main>` rather than `cd <main> && git ...`; the `cd <abs-path> && ...` shape trips the harness's untrusted-hooks gate every run. The `--is-ancestor` check exits 1 (silent, no red error) when `<default>` has advanced past the rebase point; in that case loop back to step 1 to re-rebase, then retry. Bail if the rebase itself errors. If the FF reports "Your local changes ... would be overwritten by merge" because `<main>` has unrelated uncommitted edits, stash them with `git -C <main> stash push --message "worktree-done auto-stash before FF" -- <files>`, retry the FF, and `git -C <main> stash pop` *after* step 4's `ExitWorktree`. Pop after the worktree is removed so a pop conflict resolves in a tidy state.
    3. Verify the commit is now reachable from the target branch: `git -C <main> merge-base --is-ancestor <branch> <default>`. If this exits non-zero, the merge did not land; surface "ancestry check failed: <branch> is not reachable from <default> in <main>" and stop.
    4. Call `ExitWorktree` with `action: "remove"`. It will refuse, citing N commits that "will discard this work permanently". This is a false alarm in this flow: the count is from the `EnterWorktree`-recorded base, not the merged target, so commits already reachable from `<default>` are still flagged. Once the ancestry check above has passed, re-invoke with `discard_changes: true`, the commits are preserved on `<default>`. Never pass `discard_changes: true` without verifying ancestry first.
- **User-created worktree (outside this session):** run `wtd` (`git_worktree_done` in `tools/bash/.aliases.sh`). It does the merge and cleanup atomically and enforces the same gates as the preflight. Do NOT also call `ExitWorktree` afterwards, the worktree is already gone.

If any step errors, surface the message verbatim and stop. Do not bypass the gates without asking (e.g. do not stash uncommitted changes to satisfy the clean-tree gate).

Once the worktree is gone, the session's objective is complete: apply the end-of-session prompt from `~/.claude/CLAUDE.md` (`/rename del` then `/exit`).
