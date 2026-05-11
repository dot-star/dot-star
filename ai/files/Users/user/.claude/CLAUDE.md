# User preferences

- Explicit is better than implicit.
- For temporary files, write only to the session-scoped directory `/tmp/claude/<session_id>/` (surfaced via SessionStart). Do not write directly under `/tmp/` or `/tmp/claude/`.
- When the working directory is already inside a git repository, prefer plain `git ...` invocations over `git -C <path> ...`. The cwd already has the right scope, and `-C` triggers extra permission prompts.
- Prefer long `--flag` forms over short `-f` forms when invoking shell commands. Long flags are self-describing (e.g. `grep --recursive --files-with-matches`, not `grep -rl`).
- Never use em dashes (—) in any output, code, comments, commit messages, or PR descriptions. Use a comma, parentheses, semicolon, or two sentences instead.
- Before making any code edits in a git repository, work from an isolated worktree to keep the main checkout free for parallel work. Subagents: pass `isolation: "worktree"`. Direct edits: call `EnterWorktree` first, `ExitWorktree` with `action: "remove"` when done.
- Never write single-line `if` statements; always put the body on its own line inside braces (write `if (cond) {` then `return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks; this includes side-effecting actions (e.g. `if ! git rebase master`) where chaining is possible. Plain side-effect `if`s without a terminating return stay separate.
- Self-documenting command variables: when a command's intent isn't obvious from its literal text, bind it to a descriptively-named local variable so the call site reads as prose. Example: `local is_valid_json="jq empty"` lets the conditional read `if $is_valid_json "${file}"; then`. Skip when the literal command is already clear on its own.
- Two comment shapes: block comments (TODOs, design notes) get a blank line above and below; line-doc comments (describing the next line/pipeline) stay flush with the code, no blank line between.
- To remove a symlink, suggest `unlink <path>`, not `rm <path>`. Keep `rm` / `rm -r` for regular files and directories.
- When offering the user a choice between alternatives (commit messages, refactor approaches, naming options, phrasing variants, follow-up actions), present them as a numbered list. Numbers must be globally unique across the whole response: if a reply has multiple groups of choices, number sequentially across all of them (1-3 in section A, 4-6 in section B), never restart at 1 per section. Aim for ≤9 total items so each stays a single digit; fall back to digit+letter only when more are truly needed. Does not apply to step-by-step instructions or enumerations that aren't choices.
- For commit messages, follow `~/.claude/commit-message-style.md`. Default to a single subject line; bodies are rare and reserved for non-obvious motivation.
