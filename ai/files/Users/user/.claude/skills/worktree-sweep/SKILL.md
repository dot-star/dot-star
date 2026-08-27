---
name: worktree-sweep
description: Survey every worktree in a repository, sort them into safe-to-remove vs. still-holding-work, flag orphaned directories git no longer tracks, then tear down only what the user picks. TRIGGER when the user asks which worktrees can go or asks to tear worktrees down from outside them ("tear down worktree X?", "any others to tear?", "clean up the old worktrees", "which worktrees are safe to remove?"). SKIP when the target is the worktree the session is sitting in (that is `worktree-done`), or when the user wants commits landed rather than surveyed.
---

# Worktree sweep

Goal: answer "which of these can go?" across a whole repository, then remove only the ones with nothing to lose.

`worktree-done` lands and tears down the *current* worktree. Sweep is the outside view: it never touches the current worktree and never lands anything, so every candidate it proposes is already merged.

```
                       git worktree list
                               │
        ┌──────────────────────┼──────────────────────┐
   clean tree              dirty tree            directory with no
   + fully merged          or unlanded           worktree entry
        │                  commits                     │
        ✓ safe             ✗ holds work           ! orphan (inspect first)
```

## Scope

1. Default to the repository the session is in. Resolve `<main>` from the first entry of `git worktree list` and `<default>` from the main checkout's HEAD branch (or the project's `git_default_branch` helper).
2. When the user names another repository, or says "all", repeat the survey per repository and keep each in its own block. Never merge two repositories' worktrees into one list.
3. Always exclude the worktree the session is sitting in. Tearing down the ground the session stands on is `worktree-done`'s job, and only after landing.
4. Run the survey from the main checkout. A session isolated in a worktree (via `EnterWorktree`) refuses git commands aimed at any path outside its own worktree, which is every command below. Move the session out first, or hand the sweep to a subagent started in the main checkout.

## Survey

Run per linked worktree (every `git worktree list` entry after the first, which is the main checkout). For each `<wt>`:

1. Check dirty: `git -C <wt> status --porcelain --untracked-files=all`. Carve-out: an untracked zero-byte `.claude/settings.local.json` is Claude Code's runtime permissions file, never user work, so that entry alone doesn't count as dirty. Expand untracked files individually (`--untracked-files=all`); git otherwise collapses a fully-untracked `.claude/` to `?? .claude/` and the carve-out misses. When the file is non-empty, `Read` it and show its contents in the report, since the removal deletes the accumulated rules with it.
2. Check unlanded: `git -C <wt> log --oneline <default>..HEAD`. Empty means every commit is already reachable from `<default>`.
3. Check parked: look for a `try:wt-source:<name>` entry in `git -C <main> stash list`. Such an entry means a `/try` is open and the worktree's real work is parked in the main checkout's stash, so the worktree reads clean while its changes sit elsewhere.
4. Classify: safe only when all three checks come back empty; otherwise holds-work, carrying the reason (N dirty paths, N unlanded commits, open `/try`).

A detached HEAD survives all three checks fine and just leaves no branch to delete; call it out in the report rather than skipping the worktree.

Flag anything touched in the last few minutes (the age column in `wta`) instead of proposing it: a parallel session is probably working in it right now.

## Orphans

Orphans are directories under `<main>/.claude/worktrees/` that match no `git worktree list` path, left behind by a forced removal or by metadata pruned out from under a live directory.

1. Run `git -C <main> worktree prune` first so stale administrative entries stop masking the comparison. Pruning drops git's metadata, never the leftover directory, so whatever remains unmatched afterward is a genuine orphan.
2. Inspect before proposing: list what each holds with `find <dir> -type f -o -type l`. The usual contents are a gitignored `.claude/settings.local.json` or a stale copy of a tracked file.
3. Compare any leftover copy of a tracked file against `git -C <main> show <default>:<path>` and report whether the copy is identical, an older revision, or carries edits found nowhere else.
4. Never fold an orphan into the safe list on the strength of its name. Removing one is `rm -r`, outside git entirely, so nothing brings it back.

## Report

Group by repository, then by class, safe first. One line per worktree: status glyph, name, then the evidence, padded so the glyphs stack into a scannable column. Orphans get their own block, each with what it holds.

```
example-repo
  ✓ add-export-button   clean, a1b2c3d already in master
  ✗ fix-cache-eviction  uncommitted edits (1 file)
  ✗ rework-deploy-step  2 unlanded commits + 5 staged files

  ! old-rollback-spike  holds only a gitignored settings.local.json (11 lines)
```

Always state the evidence, never a bare verdict. The user is deciding on a delete.

## Tear down

Ask before removing anything, with bracket-prefix options covering the useful splits (everything safe plus orphans / worktrees only / nothing). A survey that deletes on its own is a survey nobody trusts.

For each picked worktree, prefer the `wtd` alias (`git_worktree_done` in `tools/bash/.aliases.sh`) over hand-rolled git: `cd <wt> && wtd`. It re-runs the clean-tree gate, snapshots the worktree's permission rules through `log_permission_grants.py` before the directory disappears, fast-forwards (a no-op when the branch is already landed), removes the worktree, and deletes the branch. A hand-rolled `git worktree remove` plus `git branch --delete` skips that snapshot. `wtd` ends in the main checkout, so `cd` back into the next worktree between runs.

For each picked orphan, `rm -r <dir>`, or `unlink <path>` when the leftover is a symlink.

Verify afterward: `git -C <main> worktree list` no longer shows what was removed, and re-listing `<main>/.claude/worktrees/` no longer shows the orphans. Close with the 🏁 checklist from `~/.claude/CLAUDE.md`, one `🪓 Worktree removed` line per teardown.

If any step errors, surface the message verbatim and stop. Don't bypass a gate to make a worktree look safe (no stashing dirty files, no `--force` on a removal).
