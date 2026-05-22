---
name: worktree-promote
description: Promote a worktree's commits onto the default branch in the main checkout, leaving the worktree and branch in place to keep working. TRIGGER when cwd is inside `*/worktrees/*` and the user signals they want their commits on the default branch without wrapping up (e.g. "promote", "promote to master", "push these up but keep the worktree"), or accepts a `[p]romote` follow-up. SKIP when not in a worktree, when there are uncommitted changes the user has not addressed, or when the user wants to tear the worktree down (that is `worktree-done`).
---

# Worktree promote

Goal: fast-forward the default branch to the current worktree's branch tip in the main checkout, then stop. The worktree and its branch stay on disk so the user can keep committing. This is `worktree-done` minus the teardown: no `git worktree remove`, no branch delete, no `ExitWorktree`.

After a promote, the default branch and the worktree's branch point at the same commit. New commits in the worktree advance the branch ahead of the default again; the next promote rebases (a no-op when the default has not moved) and fast-forwards once more.

Promote and `worktree-done` share the rebase + fast-forward; they diverge only on what happens to the worktree afterward:

```
        rebase branch onto default, fast-forward default
                            │
          ┌─────────────────┴─────────────────┐
      [p]romote                            [L]and
   keep worktree + branch           remove worktree + branch
   (keep committing; promote again)        (done)
```

## Preflight

1. Confirm cwd is under `*/worktrees/*`.
2. Resolve placeholders: `<branch>` from `git symbolic-ref --short HEAD`; `<main>` from the first entry of `git worktree list`; `<default>` from the main checkout's HEAD branch (or the project's `_git_default_branch` helper).
3. Confirm working tree is clean (`git status --porcelain` empty); if not, surface the dirty paths and stop. Carve-out: an untracked empty `.claude/settings.local.json` (auto-created by Claude Code, not user work) does not count as dirty. To check, expand `?? .claude/` with `git status --porcelain --untracked-files=all` and treat the gate as satisfied when the only untracked entry is `.claude/settings.local.json` and that file is zero bytes.
4. Confirm the branch has commits ahead of `<default>` (`git log <default>..HEAD --oneline` non-empty); if not, there is nothing to promote.
5. State in one line what is about to happen ("Promoting branch X onto Z, keeping worktree Y."), then proceed. The trigger phrase already served as confirmation, do not re-prompt.

## Promote

1. Rebase the branch onto `<default>` from inside the worktree: `git rebase <default>`. This is a no-op when already up to date and avoids a noisy FF failure when `<default>` has advanced. Bail if the rebase itself errors (e.g. conflict).
2. Fast-forward in the main checkout, gated on a clean ancestry precheck so the FF never errors out with red exit 128: `cd <main> && git checkout <default> && git merge-base --is-ancestor <default> <branch> && git merge --ff-only <branch>`. Each bash tool call gets a fresh cwd (Claude Code does not persist cwd across calls), so this command must include its own `cd <main> &&` envelope. The `--is-ancestor` check exits 1 (silent, no red error) when `<default>` has advanced past the rebase point; in that case loop back to step 1 to re-rebase, then retry. If the FF reports "Your local changes ... would be overwritten by merge" because `<main>` has unrelated uncommitted edits, stash them with `cd <main> && git stash push --message "worktree-promote auto-stash before FF" -- <files>`, retry the FF, and `git stash pop` afterward.
3. Verify the commit is now reachable from the target branch: `cd <main> && git merge-base --is-ancestor <branch> <default>`. If this exits non-zero, the FF did not land; surface "ancestry check failed: <branch> is not reachable from <default> in <main>" and stop.

Do NOT remove the worktree, delete the branch, or call `ExitWorktree`. The session stays in the worktree (the FF ran inside a `cd <main> &&` subshell, so the session cwd is unchanged); confirm the commits are now on `<default>` and the worktree is intact for continued work.

If any step errors, surface the message verbatim and stop. Do not bypass the gates without asking (e.g. do not stash uncommitted worktree changes to satisfy the clean-tree gate).

The session is not done after a promote: there is more work expected in the worktree. Skip the end-of-session prompt. If the user later wants to wrap up and tear the worktree down, that is `worktree-done`.
