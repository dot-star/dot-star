# User preferences

- For temporary files, write only to the session-scoped directory `/tmp/claude-<session_id>/` (created automatically by the SessionStart hook in `~/.claude/settings.json` and surfaced to Claude as `additionalContext`). Do not write directly under `/tmp/`.
- When the working directory is already inside a git repository, prefer plain `git ...` invocations over `git -C <path> ...`. The cwd already has the right scope, and `-C` triggers extra permission prompts.
- Prefer long `--flag` forms over short `-f` forms when invoking shell commands. Long flags are self-describing (e.g. `node --check file.js`, not `node -c file.js`; `grep --recursive --files-with-matches`, not `grep -rl`).
- Never use em dashes (—) in any output, code, comments, commit messages, or PR descriptions. Use a comma, parentheses, semicolon, or two sentences instead.
- When delegating work to subagents via the Agent tool, pass `isolation: "worktree"` so changes land in a separate git worktree. This keeps the main checkout free for the user to keep working in parallel.
- Never write single-line `if` statements. Always use braces with the body on its own line, even for one-statement bodies (write `if (cond) {` then `    return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks. Plain side-effect `if`s without a terminating return stay separate.
