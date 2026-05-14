---
name: commit
description: Draft single-line commit-message options for the currently staged changes (best first), have the user pick one via AskUserQuestion, then run `git commit -m "<selection>"`. TRIGGER when the user asks for "options"/"choices" for a commit, for "numbered"/"one-liner" commit messages for staged changes, or otherwise asks Claude to draft and commit staged changes in one shot. SKIP when nothing is staged, when the user is asking only for drafts without committing, or when the user wants a multi-line body (this skill is subject-only).
---

# Commit

Collapse "draft a subject, pick one, commit" into one action for the currently staged changes.

## Preflight

1. Verify cwd is a git repo (`git rev-parse --is-inside-work-tree`).
2. Confirm something is staged: `git --no-pager diff --staged --stat`. If empty, check whether cwd is inside a session worktree (`git rev-parse --git-common-dir` differs from `git rev-parse --git-dir`); if so, run `git add --update` to stage tracked-file modifications/deletions and re-check the staged stat, otherwise surface "nothing staged" and stop.
3. Read the full staged diff: `git --no-pager diff --staged`. This is the source of truth for what to summarize.
4. Skim recent subjects for voice: `git --no-pager log --max-count=10 --format='%s'`.
5. Re-read `~/.claude/CLAUDE_commit-message-style.md` so the drafts match the user's actual style.

## Draft

Produce 4 distinct single-line subjects, ordered best-first (the one that most accurately describes the change comes first). Each must:

- Use imperative mood, capitalized first word (`Add`, `Fix`, `Update`, `Move`, `Allow`, `Enable`, `Replace`, `Rename`, `Clean up`, etc).
- Have no trailing period.
- Have no conventional-commits prefix (no `feat:`/`fix:`/`chore:`).
- Stay under 70 characters.
- Use backticks only when the literal token is the point.
- Avoid em dashes anywhere.
- Be genuinely different from the others (vary the verb, scope, or framing); skip near-duplicates.

## Pick

Call `AskUserQuestion` with a single question (`"Pick a commit message:"`, header `"Commit msg"`) and the 4 drafts as options. Put the full message in `label`, leave `description` empty or use it for a short rationale only when the framing isn't self-explanatory. `multiSelect` is false.

## Commit

Run `git commit -m "<selection>"` with the user's pick verbatim. Do not amend, do not add a body, do not append trailers. If the commit fails (e.g. pre-commit hook), surface the error verbatim and stop; do not retry with `--no-verify`.
