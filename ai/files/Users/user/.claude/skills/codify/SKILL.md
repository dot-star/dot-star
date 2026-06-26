---
name: codify
description: Promote a saved memory from soft (text Claude must remember to apply) to hard (a hook, `settings.json` entry, `CLAUDE_*.md` line, shell alias, or skill that fires automatically). Propose 2-3 candidate target shapes that fit the memory, pick one via `AskUserQuestion`, then write the change. TRIGGER when the user's whole message is exactly `codify` or `/codify` (optionally followed by a memory slug); ALSO offer it as a single follow-up sentence immediately after you save a new memory file, but only if the memory expresses a behavioral rule (feedback/project type with a clear "do X" or "when Y, do Z"). SKIP for pure user/reference facts with nothing to enforce, for fluid rules the user is still trying out, or when the target shape would duplicate existing config.
---

# Codify

Memories capture intent; codify turns intent into mechanism. Once a rule is codified, the harness (or shell, or session bootstrap) enforces it deterministically and the source memory becomes a pointer rather than the load-bearing copy.

## When to invoke

- **Explicit:** user's whole message is exactly `codify` or `/codify`, optionally followed by a memory slug (e.g. `codify feedback_quoting_style`).
- **Auto-offer:** immediately after you save a memory file, follow up with one short sentence (e.g. "Want to codify this?"). Only auto-offer for memories that express a behavioral rule. Skip the offer silently for pure user/project/reference facts.

## Subject

Codify operates on one memory file under `~/.claude/projects/<project-slug>/memory/`.

- Explicit invocation with a slug: use that memory.
- Explicit invocation without a slug: ask which memory, offering the most-recently-modified as the default.
- Auto-offer: the memory you just saved.

## Target shapes

Pick 2-3 candidates that fit the memory's content. Skip shapes that don't fit, don't pad to three.

- **Hook** in `~/.claude/settings.json`: for "every time / before X / after X" rules with a clear harness event (PreToolUse, PostToolUse, Stop, SessionStart, etc).
- **`CLAUDE_*.md` line** in `~/.claude/`: for preference-style rules that need to be loaded every session but have no event boundary (style, tone, shell conventions, output formatting).
- **`settings.json` entry** (non-hook): for permission allow/deny rules, env vars, or other harness options.
- **Shell alias or function** in `~/.dot-star/<tool>/.aliases.sh`: for workflow rules that map to a repeatable shell command. Topical aliases live with their tool.
- **Skill** at `~/.dot-star/ai/files/Users/user/.claude/skills/<name>/SKILL.md`: for multi-step workflows worth a named, explicit invocation.

For each candidate, state the concrete landing spot (file path + section) and a one-line sketch of the change. The user is picking between concrete edits, not abstract categories.

## Pick

Call `AskUserQuestion` with question `"Codify as:"`, header `"Target"`, and the 2-3 candidates as options (`multiSelect: false`). Put the target shape + landing spot in `label`; use `description` for the one-line sketch.

## Apply

1. If the target lives in a git repo (most do, especially `~/.dot-star`), work from an isolated worktree.
2. Make the change. Match the existing file's style: alphabetize JSON keys with `jq --sort-keys`, match list ordering and prose voice for markdown, follow the surrounding shell style for aliases.
3. Append a `Codified: <path>` line to the bottom of the source memory file so future runs see the rule has been promoted. Leave the memory body intact, the memory still serves as the human-readable rationale.
4. If inside a git repo, stage and commit using the `commit` skill flow.
5. Report in one line where it landed.

## Skip conditions

- Memory is a pure user/project/reference fact with no rule to enforce (e.g. "user is a Go dev", "bugs tracked in Linear INGEST"). Auto-offer should not fire at all in this case.
- The rule is still fluid (user signalled "let's try this for now", "tentative", or similar). Codifying prematurely is harder to undo than editing the memory.
- The target shape would duplicate existing config. Surface the existing entry instead.
