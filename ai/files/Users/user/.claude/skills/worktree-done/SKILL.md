---
name: worktree-done
description: Land a worktree's commits back into the default branch in the main checkout and remove the worktree. TRIGGER when cwd is inside `*/worktrees/*` and the user signals work is done (e.g. "ship it", "land it", "merge it back", "clean up the worktree", "wrap this up"). SKIP when not in a worktree, when there are uncommitted changes the user has not addressed, or when the user is mid-task.
---

# Worktree done

Goal: collapse "merge worktree branch back, remove worktree, delete branch" into one action, run from inside the worktree.

## Preflight

1. Confirm cwd is under `*/worktrees/*`.
2. Resolve placeholders: `<branch>` from `git symbolic-ref --short HEAD`; `<main>` from the first entry of `git worktree list`; `<default>` from the main checkout's HEAD branch (or the project's `_git_default_branch` helper).
3. Confirm working tree is clean (`git status --porcelain` empty); if not, surface the dirty paths and stop.
4. Confirm the branch has commits ahead of `<default>` (`git log <default>..HEAD --oneline` non-empty); if not, there is nothing to land.
5. State in one line what is about to happen ("Landing branch X from worktree Y into Z and removing the worktree."), then proceed. The trigger phrase already served as confirmation, do not re-prompt.

## Land

Two paths, depending on how the worktree was created:

- **EnterWorktree-managed (this session created it via the `EnterWorktree` tool):** do the merge manually so `ExitWorktree`'s session tracking stays in sync.
    1. Merge in the main checkout, all in one bash call: `builtin cd <main> && git checkout <default> && git merge --ff-only <branch>`. Plain `cd` is intercepted by the `conditional_cd` alias and silently no-ops in Claude's non-interactive subshell, which would run the merge in the wrong repo; `builtin cd` is the same workaround `wtd` itself uses. If the FF fails, run `git rebase <default>` inside the worktree (cwd is already there), then retry the FF in main.
    2. Verify the commit is now reachable from the target branch: `(builtin cd <main> && git merge-base --is-ancestor <branch> <default>)`. If this exits non-zero, the merge did not land; surface "ancestry check failed: <branch> is not reachable from <default> in <main>" and stop.
    3. Call `ExitWorktree` with `action: "remove"`. It will refuse, citing N commits that "will discard this work permanently". This is a false alarm in this flow: the count is from the `EnterWorktree`-recorded base, not the merged target, so commits already reachable from `<default>` are still flagged. Once the ancestry check above has passed, re-invoke with `discard_changes: true`, the commits are preserved on `<default>`. Never pass `discard_changes: true` without verifying ancestry first.
- **User-created worktree (outside this session):** run `wtd` (`git_worktree_done` in `bash/.aliases.sh`). It does the merge and cleanup atomically and enforces the same gates as the preflight. Do NOT also call `ExitWorktree` afterwards, the worktree is already gone.

If any step errors, surface the message verbatim and stop. Do not bypass the gates without asking (e.g. do not stash uncommitted changes to satisfy the clean-tree gate).
