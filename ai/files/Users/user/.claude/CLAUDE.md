# User preferences

## Principles

- Explicit is better than implicit.
- Atomic commits: one logical change per commit.
- Optimize for readability and reviewer happiness.
- Pursue correctness across the task; accept more churn when minimalist diffs and correctness conflict.
- Organize this file semantically by topic, not by order added.
- Within lists, sort items by natural alphabetical (case-insensitive) of the leading identifier (first backticked token, proper noun, or word). Skip when the order encodes meaning (steps, priorities, dependencies, manifesto hierarchies).

## Supplemental preferences

- On session start, before acting on any user message, list `~/.claude/` and read every file matching `CLAUDE_*.md` in version-sort order (`sort --version-sort`: numeric components compared as numbers, un-numbered names alphabetical after numbered). Example order: `CLAUDE_01_private.md`, `CLAUDE_03_company.md`, `CLAUDE_10_workflow.md`, `CLAUDE_slack-style.md`, `CLAUDE_testing.md`. Treat each as preferences layered on top of this file; later files override earlier ones on conflict.

## Workflow

- For temporary files, write only to the session-scoped directory `/tmp/claude/<session_id>/` (surfaced via SessionStart). Do not write directly under `/tmp/` or `/tmp/claude/`.
- Before making any code edits in a git repository, work from an isolated worktree to keep the main checkout free for parallel work. Subagents: pass `isolation: "worktree"`. Direct edits: call `EnterWorktree` first, `ExitWorktree` with `action: "remove"` when done.
- When the working directory is already inside a git repository, prefer plain `git ...` invocations over `git -C <path> ...`. The cwd already has the right scope, and `-C` triggers extra permission prompts.
- When the session's objective is complete (worktree landed, task done, question answered), prompt the user to mark the session for prune with `/rename del` then `/exit`. Prefix the prompt with ✅ followed by a one-line recap of the completed objective, so it's visually distinct from the surrounding work and confirms what was finished. `ai/claude/prune.sh` later sweeps any session whose custom title matches its `target_titles` list (includes `del`). Do not start fresh work in the same session unless the user signals otherwise.

## Shell commands

- Prefer long `--flag` forms over short `-f` forms when invoking shell commands. Long flags are self-describing (e.g. `grep --recursive --files-with-matches`, not `grep -rl`).
- To remove a symlink, suggest `unlink <path>`, not `rm <path>`. Keep `rm` / `rm -r` for regular files and directories.

## Code style

- Never write single-line `if` statements; always put the body on its own line inside braces (write `if (cond) {` then `return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks; this includes side-effecting actions (e.g. `if ! git rebase master`) where chaining is possible. Plain side-effect `if`s without a terminating return stay separate.
- Self-documenting command variables: when a command's intent isn't obvious from its literal text, bind it to a descriptively-named local variable so the call site reads as prose. Example: `local is_valid_json="jq empty"` lets the conditional read `if $is_valid_json "${file}"; then`. Skip when the literal command is already clear on its own.
- Two comment shapes: block comments (TODOs, design notes) get a blank line above and below; line-doc comments (describing the next line/pipeline) stay flush with the code, no blank line between.
- Blank lines around `if` blocks track logical grouping. Keep an assignment flush with the `if` that consumes its result (`x="$(...)"` immediately above `if [[ -z "${x}" ]]; then`); same for consecutive assignments feeding the same conditional. Insert a blank line above standalone `if`s not fed by the previous line, after a closing `fi`, and after the function's `local` declaration block. A line-doc comment describing the `if` stays flush with it, so the blank line goes above the comment.

## Styles

On-demand style guides live under `~/.claude/styles/`. Read the relevant file when starting work in that area; do not auto-load.

- For commit messages, follow `~/.claude/styles/commit-message-style.md`. Default to a single subject line; bodies are rare and reserved for non-obvious motivation.
- For shell scripts (bash, zsh), follow `~/.claude/styles/shell-style.md`.

## Input

- Interpret bare one-word/one-token user replies as shorthand. Fires only when the entire message is exactly that token; if the message starts with a question word (what/how/why/is/should/can/does/...) it's a question *about* the token, not an invocation.
  - `y`, `ya` mean "yes" (treat as a `y/n?` style answer)
  - `n`, `no`, `nope` mean "no"
  - `res` means "resume"
  - `cont` means "continue"
  - `re` means "retry"
  - `eg`, `examples` mean "show me examples"
  - `🚢` means "ship it" (land the work)

## Shorthand

- Interpret these tokens as shorthand for the named referent when they appear inside a user message (not as a whole reply). These are **input-only**: expand them when reading user input, and always write the full word ("clipboard", "root", "worktree") in own output. Never echo the shorthand back in status updates, prose, or commit messages.
  - `cb` means "clipboard"
  - `r` means "root" (the main checkout, vs. a worktree)
  - `wt` means "worktree"

## Output

- Never use em dashes (—) in any output, code, comments, commit messages, or PR descriptions. Use a comma, parentheses, semicolon, or two sentences instead.
- Never emit `cb`, `r`, or `wt` as standalone tokens in own output; always expand to "clipboard" / "root" / "worktree". These are input-only shorthand (see the Shorthand section above) and reading them back as jargon obscures meaning.
- When offering the user a choice between alternatives (commit messages, refactor approaches, naming options, phrasing variants, follow-up actions), present them as a numbered list. Numbers must be globally unique across the whole response: if a reply has multiple groups of choices, number sequentially across all of them (1-3 in section A, 4-6 in section B), never restart at 1 per section. Aim for ≤9 total items so each stays a single digit; fall back to digit+letter only when more are truly needed. Does not apply to step-by-step instructions or enumerations that aren't choices.
- When a choice is *visual* (colors, ANSI styling, layout, formatting, rendering variants, anything the user judges by appearance), each option MUST include a concretely rendered sample, never just a prose description like "orange background, black text". This applies to numbered chat choices AND to `AskUserQuestion` options. The question tool's option label/description fields can't render ANSI, so when the visual is ANSI-only, emit the rendered samples in a numbered list in chat text (one rendered artifact per line, stacked) BEFORE or INSTEAD OF calling `AskUserQuestion`, and let the user reply with the number. Describing the difference in words and expecting the user to mentally render it forces a wasted round-trip.
- When a numbered choice option ends in `: <rendered example>` (sample line, code snippet, prompt phrasing, anything the user compares visually), break after the `:` so the rendered artifact starts on its own line at the same indent across options. The artifacts then stack vertically and the user can diff them top-to-bottom instead of hunting them out of wrapped prose. Skip when the artifact is a single short token that already fits inline without wrapping, or when the choice is purely semantic with no rendered artifact.
- Chat color palette by surface: inline prose has three accents (plain inline-code, bold-inline-code per the bracket-prefix trick, link blue); fenced code blocks get the full syntax-highlight palette of the chosen lexer; status line bypasses markdown and supports full ANSI (8/256/truecolor). When asked about chat colors, distinguish the surface before claiming a limit, and reach for a fenced block when multi-color is needed and prose-inline isn't. Rendered example, file:line in a `python` fence so `42` shows in number-color:

  ```python
  src/foo.py:42
  ```
- For short inline prose binary/ternary asks (a single question in running text, not a numbered list): every option must carry its own bracketed accept-prefix, no exceptions. Before sending, count the "or"-separated options and verify each one contains a `[` ... `]` pair; if any option lacks one, fix it. An option that mentions a command, tool, slash-command, or other keyword (e.g. "land with `worktree-done`") still needs its own bracketed letter, since the keyword does not double as the accept token. Wrap the whole option (bracket prefix + remainder) in a single bold inline-code span so the brackets, inner letter(s), and remainder all share the same color and weight and the accept key visually pops: source form is `**` + `` ` `` + `[` + letter(s) + `]` + remainder + `` ` `` + `**`. Rendered example: "Want me to commit this as a **`[f]ollow-up`**, or **`[a]mend`** the previous commit?". Accept the bracketed prefix (case-insensitive) as a complete reply and map it back to the full option. Prefer the single-letter prefix (rendered **`[a]mend`**); extend to multi-character (rendered **`[am]end`** vs **`[ad]d`**) only when two options would otherwise share the same letter.
- When an own `[c]ommit` follow-up offer is accepted (reply `c`/`cm`/`commit`/🚢 mapped to the commit option), invoke the `commit` skill via the `Skill` tool rather than running `git commit -m "<self-chosen subject>"` directly. The skill drafts numbered subject options for the user to pick; auto-picking bypasses that choice. Same rule for any other phrasing where the offered action was "commit" (e.g. **`[c]ommit and land`**, "want me to commit?"). To commit without the skill, the user has to opt in explicitly.
