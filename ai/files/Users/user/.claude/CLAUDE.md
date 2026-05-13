# User preferences

## Principles

- Explicit is better than implicit.
- Organize this file semantically by topic, not by order added.

## Supplemental preferences

- On session start, before acting on any user message, list `~/.claude/` and read every file matching `CLAUDE_*.md` in version-sort order (`sort --version-sort`: numeric components compared as numbers, un-numbered names alphabetical after numbered). Example order: `CLAUDE_01_private.md`, `CLAUDE_03_company.md`, `CLAUDE_10_workflow.md`, `CLAUDE_slack-style.md`, `CLAUDE_testing.md`. Treat each as preferences layered on top of this file; later files override earlier ones on conflict.

## Workflow

- For temporary files, write only to the session-scoped directory `/tmp/claude/<session_id>/` (surfaced via SessionStart). Do not write directly under `/tmp/` or `/tmp/claude/`.
- Before making any code edits in a git repository, work from an isolated worktree to keep the main checkout free for parallel work. Subagents: pass `isolation: "worktree"`. Direct edits: call `EnterWorktree` first, `ExitWorktree` with `action: "remove"` when done.
- When the working directory is already inside a git repository, prefer plain `git ...` invocations over `git -C <path> ...`. The cwd already has the right scope, and `-C` triggers extra permission prompts.
- For commit messages, follow `~/.claude/commit-message-style.md`. Default to a single subject line; bodies are rare and reserved for non-obvious motivation.

## Shell commands

- Prefer long `--flag` forms over short `-f` forms when invoking shell commands. Long flags are self-describing (e.g. `grep --recursive --files-with-matches`, not `grep -rl`).
- To remove a symlink, suggest `unlink <path>`, not `rm <path>`. Keep `rm` / `rm -r` for regular files and directories.

## Code style

- Never write single-line `if` statements; always put the body on its own line inside braces (write `if (cond) {` then `return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks; this includes side-effecting actions (e.g. `if ! git rebase master`) where chaining is possible. Plain side-effect `if`s without a terminating return stay separate.
- Self-documenting command variables: when a command's intent isn't obvious from its literal text, bind it to a descriptively-named local variable so the call site reads as prose. Example: `local is_valid_json="jq empty"` lets the conditional read `if $is_valid_json "${file}"; then`. Skip when the literal command is already clear on its own.
- Two comment shapes: block comments (TODOs, design notes) get a blank line above and below; line-doc comments (describing the next line/pipeline) stay flush with the code, no blank line between.
- Blank lines around `if` blocks track logical grouping. Keep an assignment flush with the `if` that consumes its result (`x="$(...)"` immediately above `if [[ -z "${x}" ]]; then`); same for consecutive assignments feeding the same conditional. Insert a blank line above standalone `if`s not fed by the previous line, after a closing `fi`, and after the function's `local` declaration block. A line-doc comment describing the `if` stays flush with it, so the blank line goes above the comment.

## Input

- Interpret bare one-word/one-token user replies as shorthand: `y` and `ya` mean "yes" (treat as a `y/n?` style answer); `n`, `no`, and `nope` mean "no"; `res` means "resume"; `🚢` means "ship it" (land the work). Fires only when the entire message is exactly that token; if the message starts with a question word (what/how/why/is/should/can/does/...) it's a question *about* the token, not an invocation.

## Output

- Never use em dashes (—) in any output, code, comments, commit messages, or PR descriptions. Use a comma, parentheses, semicolon, or two sentences instead.
- When offering the user a choice between alternatives (commit messages, refactor approaches, naming options, phrasing variants, follow-up actions), present them as a numbered list. Numbers must be globally unique across the whole response: if a reply has multiple groups of choices, number sequentially across all of them (1-3 in section A, 4-6 in section B), never restart at 1 per section. Aim for ≤9 total items so each stays a single digit; fall back to digit+letter only when more are truly needed. Does not apply to step-by-step instructions or enumerations that aren't choices.
