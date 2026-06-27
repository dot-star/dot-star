---
name: commit
description: Draft single-line commit-message options for the currently staged changes (best first), have the user pick one via AskUserQuestion, then run `git commit -m "<selection>"`. TRIGGER when the user asks for "options"/"choices" for a commit, for "numbered"/"one-liner" commit messages for staged changes, or otherwise asks Claude to draft and commit staged changes in one shot. ALSO TRIGGER when the user accepts a `[c]ommit` follow-up that Claude offered (replies `c`, `cm`, `commit`, or 🚢 mapped to such an option); the accepted offer counts as a request for options, never auto-pick a subject and `git commit -m` directly. SKIP when nothing is staged, when the user is asking only for drafts without committing, or when the user wants a multi-line body (this skill is subject-only).
---

# Commit

Collapse "draft a subject, pick one, commit" into one action for the currently staged changes.

## Preflight

1. Verify cwd is a git repo (`git rev-parse --is-inside-work-tree`).
2. Confirm something is staged. The preflight branches by cwd; cwd is a linked worktree when `git rev-parse --git-common-dir` differs from `git rev-parse --git-dir`, otherwise it's the root checkout.

   ```
   cwd
   ├── worktree
   │   └── git diff --staged --stat
   │       ├── non-empty → proceed to step 3
   │       └── empty
   │           ├── git add --update
   │           └── re-check staged → proceed, or stop ("nothing staged")
   └── root
       └── git diff --staged --stat
           ├── non-empty → proceed to step 3
           └── empty
               ├── git add --update
               └── re-check staged → proceed, or stop ("nothing staged")
   ```

   `git add --update` stages tracked-file modifications/deletions only; untracked files (`??`) are never auto-staged.
3. Read the full staged diff: `git --no-pager diff --staged`. This is the source of truth for what to summarize.
4. Skim recent subjects for voice: `git --no-pager log --max-count=10 --format='%s'`.
5. Re-read `~/.claude/CLAUDE_commit-message-style.md` so the drafts match the user's actual style.

## Draft

Produce 6 distinct single-line subjects (over-generate so the true best is in the pool, not just the first thing drafted), then score and rank them with the weighted sheet below, and keep only the top 3 to present.

Score each draft 0, 1, or 2 on every criterion, multiply by the criterion's weight, sum to a total, then sort best-first by total descending. The descending weights keep the earlier criteria dominant (a self-contained subject almost always outranks a merely-tight one), but the continuous total lets a draft that's slightly weaker on one criterion still win when it's far stronger on the rest, which a strict lexicographic tiebreak can't express.

| Weight | Criterion | 2 (full) | 0 (fail) |
| --- | --- | --- | --- |
| ×5 | **Self-contained** | a reader who hasn't seen the diff understands what changed from the subject alone ("Reject uploads larger than 10 MB") | opaque without the diff ("Update handler") |
| ×4 | **Names the concrete thing** | the specific value or behavior ("Raise the upload limit to 50 MB") | a vague category ("Adjust upload settings") |
| ×3 | **Intent over mechanism** | what changed and why | where it landed; locational filler like "in Principles" |
| ×2 | **Imperative, verb-first** | `Add`, `Prefer`, `Fix` | `Note`, `Adds` |
| ×1 | **Tightest phrasing** | no slack left without losing specificity | padded with words the diff already carries |

On a tie in total, break it toward the higher self-contained score, then the higher concrete-thing score. Score honestly: don't inflate a draft to pad the pool, a 4-way tie at the top means the drafts aren't distinct enough, so revise before ranking.

Each subject must:

- Use imperative mood, capitalized first word (`Add`, `Fix`, `Update`, `Move`, `Allow`, `Enable`, `Replace`, `Rename`, `Clean up`, etc).
- Have no trailing period.
- Have no conventional-commits prefix (no `feat:`/`fix:`/`chore:`).
- Stay under 70 characters.
- Use backticks only when the literal token is the point.
- Avoid em dashes anywhere.
- Be genuinely different from the others (vary the verb, scope, or framing); skip near-duplicates.

## Pick

Call `AskUserQuestion` with a single question (`"Pick a commit message:"`, header `"Commit msg"`) and the top 3 drafts as options, in best-first order. Put the full message in `label`, leave `description` empty or use it for a short rationale only when the framing isn't self-explanatory. `multiSelect` is false.

## Commit

Run `git commit -m "<selection>"` with the user's pick verbatim. Don't amend, don't add a body, don't append trailers. If the commit fails (e.g. pre-commit hook), surface the error verbatim and stop; don't retry with `--no-verify`.

## Follow-up

After the commit lands, branch on cwd (worktree when `git rev-parse --git-common-dir` differs from `git rev-parse --git-dir`, otherwise root):

- **Worktree:** offer the next step as an inline bracket-prefix choice: **`[p]romote`** (fast-forward the default branch to this branch tip and keep the worktree to keep working, via the `worktree-promote` skill), **`[L]and`** (promote and tear down, via `worktree-done`), or keep iterating. The two share a first step; `[p]romote` keeps the worktree, `[L]and` removes it. Don't auto-run either; wait for the user's pick.
- **Root:** no promote/land follow-up; the commit is already on the working branch.
