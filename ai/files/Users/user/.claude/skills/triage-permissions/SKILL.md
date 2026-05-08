---
name: triage-permissions
description: Triage `.claude/settings.local.json` in the current project: drop entries already covered by `~/.dot-star`, drop path-pinned or one-off probes, and promote the rest to the dot-star-managed `~/.claude/settings.json` as `Bash(<cmd> *)` wildcards. Then delete the local file if its allow list ends empty. TRIGGER when the user mentions `settings.local.json`, asks why Claude keeps prompting for the same thing, talks about the allowlist or denylist, or when a `SessionStart` hook surfaces a reminder that the file has accumulated entries. SKIP when the project has no `.claude/settings.local.json`, or the user is asking about general settings.json structure rather than cleanup.
---

# Triage permissions

Goal: keep `.claude/settings.local.json` empty by promoting reusable rules to the dot-star-managed user-global file at `~/.dot-star/ai/files/Users/user/.claude/settings.json` (symlinked to `~/.claude/settings.json`), so every project on this machine and every machine running these dotfiles benefits.

## Procedure

Work in a worktree. Edit the worktree's copy of the global file, not the main checkout (absolute paths to the main checkout will silently miss it).

For each entry in `permissions.allow` and `permissions.deny` of `.claude/settings.local.json`:

- **Drop** if already covered by the global file.
- **Drop** if it's path-pinned to this checkout (references absolute repo paths) or uses `git -C <path>`.
- **Drop** if it's a one-off feature probe (`--version`, `--help`, single-shot diagnostics).
- **Promote** otherwise: generalize the literal command to its `Bash(<cmd> *)` wildcard, and add it to the matching list in the global file alphabetically, matching the existing space-asterisk style.

After edits:

1. Validate the global file with `command jq empty`.
2. If `/config` reordered top-level keys, re-sort them with `command jq --sort-keys`.
3. Delete `.claude/settings.local.json` if its `allow` list ends empty (`rm`, not `unlink`, since it's a regular file).
4. List 2-4 numbered one-liner commit-message options, sorted best-first, and commit the user's pick.

## Reporting

Before editing, show the user a short table mapping each local entry to its disposition (drop / promote-as-X) and wait for confirmation if any judgment calls are non-obvious.
