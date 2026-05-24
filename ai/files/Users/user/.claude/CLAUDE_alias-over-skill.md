# Prefer shell alias over skill

Before invoking the Skill tool, check whether a shell function/alias in the dot-star tree (`~/.dot-star/bash/.*.sh`, `~/.dot-star/<tool>/.aliases.sh`) already encodes the same flow. If so, run the alias via Bash; it's one tool call vs. the skill's multi-step procedure.

## Known equivalents

- `worktree-done` skill → `wtd` (`git_worktree_done` in `bash/.aliases.sh`)
- `worktree-promote` skill → `promote` (`git_worktree_promote` in `bash/.aliases.sh`)

## When the skill is still the right call

The skill is correct only when its body does something the alias doesn't. For the worktree skills specifically: when *this* session created the worktree via the `EnterWorktree` tool, the skill drives `ExitWorktree` so the harness's session tracking stays in sync; `wtd`/`promote` would leave the tracker stale. Outside that case, prefer the alias.

## Apply

- Default to the alias for user-created worktrees (`git worktree add ...`).
- After the alias returns, still apply any end-of-session prompts the skill would have triggered (e.g. 🏁 + `/rename del` + `/exit` from `CLAUDE.md`).
- When unsure whether an alias exists for a skill's flow, `grep -nE "^alias |^[a-z_][a-z_0-9]*\(\) \{$" bash/.*.sh */.aliases.sh` before reaching for `Skill`. Many aliases live in topical `bash/.<name>.sh` files (cd, data_*, safer_rm, pomodoro, conditionals), not only `*.aliases.sh`.
