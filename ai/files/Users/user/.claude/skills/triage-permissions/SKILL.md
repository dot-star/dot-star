---
name: triage-permissions
description: Triage `.claude/settings.local.json` in the current project: pre-filter out entries already covered by `~/.dot-star`, path-pinned, one-off probes, or too specific to recur, then ask per surviving entry whether to promote it to the dot-star-managed `~/.claude/settings.json` as a `Bash(<cmd> *)` wildcard. Then delete the local file if its allow list ends empty. TRIGGER when the user mentions `settings.local.json`, asks why Claude keeps prompting for the same thing, talks about the allowlist or denylist, or when a `SessionStart` hook surfaces a reminder that the file has accumulated entries. SKIP when the project has no `.claude/settings.local.json`, or the user is asking about general settings.json structure rather than cleanup.
---

# Triage permissions

Goal: keep `.claude/settings.local.json` empty by promoting reusable rules to the dot-star-managed user-global file at `~/.dot-star/ai/files/Users/user/.claude/settings.json` (symlinked to `~/.claude/settings.json`), so every project on this machine and every machine running these dotfiles benefits.

## Procedure

Two files are in play; they live in different checkouts, so resolve both to absolute paths before touching anything.

- **Local file** (triage target): the project's `.claude/settings.local.json`. Always lives in the **main checkout** of the project being triaged, never in a worktree. From inside a worktree the bare path `.claude/settings.local.json` resolves to the worktree's own empty `.claude/`, not the file you want. Resolve it with:

  ```bash
  main_repo_root="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
  local_file="${main_repo_root}/.claude/settings.local.json"
  ```

  Use `${local_file}` everywhere below.

- **Global file** (promotion target): `~/.dot-star/ai/files/Users/user/.claude/settings.json`. Edit the worktree's copy so the change can be committed (absolute paths to the main dot-star checkout silently miss it).

Work in a worktree of dot-star for the edits.

Triage runs in two passes over the entries in `permissions.allow` and `permissions.deny` of `${local_file}`: a silent pre-filter that auto-drops the obvious, then a per-entry yes/no ask on whatever survives.

### Pass 1: pre-filter (no prompts)

Auto-drop any entry matching one of these. None is worth a question.

- **Covered**: already in the global file.
- **One-off probe**: `--version`, `--help`, single-shot diagnostics.
- **Path-pinned**: references absolute repo paths, or uses `git -C <path>`.
- **Too specific to recur**: a literal command unlikely to come up again in this or any other project (a long pipeline, a one-time data munge, an argument set tied to today's task).

Whatever's left after the pre-filter is the ask list.

### Pass 2: ask per entry

Go through the ask list one entry at a time and let the user decide each independently, rather than lumping them into a single batch confirmation. For each, propose the `Bash(<cmd> *)` generalization and ask a yes/no: promote it to the global file, or drop it. Batch up to a few at a time with `AskUserQuestion` (one question per entry, each with **Promote** / **Drop** options) so a long list doesn't become one round-trip per entry, but keep the decisions per-entry.

On **promote**: add the wildcard to the matching list in the global file alphabetically, matching the existing space-asterisk style. On **drop**: leave it out.

After edits:

1. Validate the global file with `command jq empty`.
2. If `/config` reordered top-level keys, re-sort them with `command jq --sort-keys`.
3. Delete `${local_file}` if its `allow` list ends empty (`rm`, not `unlink`, since it's a regular file).
4. Commit the change via the `/commit` skill.

## Reporting

Lead with a compact list of what the pre-filter auto-dropped (one line each, with the reason), so the user can see what was skipped without being asked about it. Then run the per-entry asks. If the pre-filter and ask list are both empty, say so and stop.
