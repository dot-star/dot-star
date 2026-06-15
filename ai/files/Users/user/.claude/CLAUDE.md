# User preferences

## Principles

- Explicit is better than implicit.
- Atomic commits: one logical change per commit.
- Optimize for readability and reviewer happiness.
- Pursue correctness across the task; accept more churn when minimalist diffs and correctness conflict.
- A refactor preserves behavior exactly. Any observable change (return value, status code, error path, output) means it is not a refactor: flag it and get sign-off, never fold it in silently.
- Stay within the task's scope. Don't opportunistically rewrite, reword, or delete untouched code or comments; a cleanup is its own change.
- Prefer robust over brittle solutions: favor approaches that tolerate change.
- Touched code self-heals, ratcheting toward the preferred style. When a documented preference (in `CLAUDE.md` or memory) conflicts with the local style, the lines your edit modifies must end in the preferred form; untouched lines nearby stay as-is. Land the style swap as a separate atomic commit; order relative to the feature commit doesn't matter.
- Upgrade early, upgrade often. Small frequent upgrades are cheap; deferred ones compound in difficulty, risk, and security exposure.
- Organize this file semantically by topic, not by order added.
- Within lists, sort items by natural alphabetical (case-insensitive) of the leading identifier (first backticked token, proper noun, or word). Skip when the order encodes meaning (steps, priorities, dependencies, manifesto hierarchies).

## Supplemental preferences

- Sibling `~/.claude/CLAUDE_*.md` files are auto-injected into the session context by a `SessionStart` hook, in version-sort order (`sort --version-sort`: numeric components compared as numbers, un-numbered names alphabetical after numbered). Example order: `CLAUDE_01_<name>.md`, `CLAUDE_03_<name>.md`, `CLAUDE_10_workflow.md`, `CLAUDE_testing.md`. Treat each as preferences layered on top of this file; later files override earlier ones on conflict.

## Workflow

- For temporary files, write only to the session-scoped directory `/tmp/claude/<session_id>/` (surfaced via SessionStart). Do not write directly under `/tmp/` or `/tmp/claude/`.
- Before making any code edits in a git repository, work from an isolated worktree to keep the main checkout free for parallel work. Subagents: pass `isolation: "worktree"`. Direct edits: call `EnterWorktree` first, `ExitWorktree` with `action: "remove"` when done.
- When the working directory is already inside a git repository, prefer plain `git ...` invocations over `git -C <path> ...`. The cwd already has the right scope, and `-C` triggers extra permission prompts.
- `~/.claude/` is wired into `~/.dot-star/ai/files/Users/user/.claude/` two ways. Whole-directory symlinks: `commands/`, `hooks/`, `skills/`, `styles/` (a new file inside any of these auto-surfaces, no per-file symlink needed). Per-entry file symlinks: `CLAUDE.md`, `settings.json` (a new top-level entry needs its own `ln -s <real-path> ~/.claude/<name>`). Always write/edit at the real dot-star path; `Edit`/`Write` refuse to write through symlinks.
- On the first user message of a session, write a caveman-style summary of their intent (drop articles, pronouns, aux verbs; aim for ≤60 chars) to `/tmp/claude/<session_id>/objective` as a single line. Use the `Write` tool, not a Bash `printf`/`mkdir` redirect: the SessionStart hook already created the session dir, and `Write(//tmp/claude/**)` is allowlisted, so the `Write` tool needs no permission prompt while the compound Bash command does. The statusline hook reads this file as the displayed objective (truncated past 60 chars), and falls back to the raw first message if the file is missing. Rewrite the file if the intent shifts substantially during the session.
- When the session's objective is complete (worktree landed, task done, question answered), prompt the user to mark the session for prune with `/rename del` then `/exit`. Prefix the prompt with 🏁 followed by a one-line recap of the completed objective, so it's visually distinct from the surrounding work and confirms what was finished. `ai/claude/prune.sh` later sweeps any session whose custom title matches its `target_titles` list (includes `del`). Do not start fresh work in the same session unless the user signals otherwise.

## Shell commands

- Dot-star manages the user's dotfiles at `~/.dot-star/`; aliases and short commands referenced in chat are defined in `*/.aliases.sh` files fanned out across per-tool dirs. Grep `~/.dot-star/` before asking.
- Prefer long `--flag` forms over short `-f` forms when invoking shell commands. Long flags are self-describing (e.g. `grep --recursive --files-with-matches`, not `grep -rl`).
- To remove a symlink, suggest `unlink <path>`, not `rm <path>`. Keep `rm` / `rm -r` for regular files and directories.

## Code style

- Never write single-line `if` statements; always put the body on its own line inside braces (write `if (cond) {` then `return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks; this includes side-effecting actions (e.g. `if ! git rebase master`) where chaining is possible. Plain side-effect `if`s without a terminating return stay separate.
- Two comment shapes: block comments (TODOs, design notes) get a blank line above and below; line-doc comments (describing the next line/pipeline) stay flush with the code, no blank line between.
- Comments lead with WHAT (imperative verb + object) before WHY. Good: `# Strip geometry lines around each gitk run. The file is symlinked and gitk rewrites them on exit.` Bad (WHY first): `# gitk rewrites geometry lines on exit; strip them around each run so the symlinked config stays clean.` Bad (noun-phrase title, no verb): `# Vim swap files`; don't pattern-match local title-style comments, the new line ratchets to the imperative form per "touched code self-heals." The rule binds EVERY comment line, not just the first: each line of a multi-line comment, and each entry of a key→action or value→action mapping list, leads with its own imperative verb (`// Show fewer days with "-".`, not `// "-" fewer days.`). Before finishing any edit that adds or touches a comment, scan each new comment line and confirm its first word is an imperative verb; a continuation or list sub-line that fronts a key, value, or noun phrase is the common miss.
- Start every TODO with an unambiguous action verb (`Add`, `Show`, `Fix`, `Render`, `Plot`, `Wire`, `Move`, `Replace`, `Remove`, `Rename`, `Drop`), in code comments (`// TODO:`, `# TODO:`) and task-list entries (`todo.md`, `TODO`, `tasks.md`, README task sections) alike. Avoid leaders that read as nouns first (`Surface`, `File`, `Mark`, `Plant`, `Brief`); they're valid verbs but parse as nouns at a glance, breaking scan-ability.
- Match the file's existing line-wrapping convention; don't hard-wrap prose or markdown to a column. If the surrounding bullets/paragraphs each run one line, keep yours on one line too. Only wrap where the existing lines already wrap.
- Build multi-line strings so the source mirrors the rendered output: one statement per output line, each carrying a literal newline, not several `\n` escapes packed into one long line. The split makes the rendered shape visible in the source and keeps diffs line-addressable. A `\n` mid-string is still fine (a header's trailing `\n\n` stays inline). Per-language idioms live in the matching style guide.
- Instruction docs (`CLAUDE.md`, `CLAUDE_*.md`, READMEs) are read by humans too, not just the AI; whenever a rule is best served by structure (a long clause-dense line is the common trigger, not the only one), spend whatever improves readability: whitespace, nested sub-bullets, a table, even an ASCII diagram. These aids serve the human reader and don't count as the column-wrapping the previous rule forbids.

## Styles

Style guides live under `~/.claude/styles/`. Don't bulk-load them all; instead, before writing or editing a file, read and apply the one matching its type, so code lands in the preferred style by default and never only when asked. A `PreToolUse` hook (`remind_style_guide.sh`) injects the matching guide's path on each `Write`/`Edit` as a reminder, but the obligation to read and apply it stands with or without the nudge.

- For commit messages, follow `~/.claude/styles/commit-message-style.md`. Default to a single subject line; bodies are rare and reserved for non-obvious motivation.
- For new file names, follow `~/.claude/styles/file-naming-style.md`. Apply when creating any file: hierarchical prefix groups related files, self-describing remainder says what the file does.
- For Python docstrings (tests, functions, classes, modules), follow `~/.claude/styles/python-docstring-style.md`. One-line default; multi-line only when contract, contrast, non-obvious WHY, or setup demands it.
- For shell scripts (bash, zsh), follow `~/.claude/styles/shell-style.md`.

## Input

- Interpret a bare one-token reply or a short fixed phrase as shorthand. Fires only when the entire message is exactly that token or phrase; if the message starts with a question word (what/how/why/is/should/can/does/...) it's a question *about* the token, not an invocation.
  - `y`, `ya` mean "yes" (treat as a `y/n?` style answer)
  - `n`, `no`, `nope` mean "no"
  - `res` means "resume"
  - `cont` means "continue"
  - `re` means "retry"
  - `eg`, `examples` mean "show me examples"
  - `flow`, `ascii`, `ascii flow` mean "render the thing under discussion (a pipeline, control flow, data flow, architecture) as an ASCII diagram with boxes and arrows"
  - `defend`, `prove` mean "defend/prove the prior reply" (justify each claim or item in it)
  - `harden`, `bake`, `firm` mean "strengthen the rule i just hit" by tightening it in `CLAUDE.md` or the matching `CLAUDE_*.md` sibling, or promoting it there from memory if that's where it lives. Memory isn't durable enough to harden into.
  - `t`, `trim` mean "condense whatever we're working on (a comment, a sentence, a rule, a block of code) without losing meaning": rewrite it shorter while preserving every constraint or detail, and flag anything that can't be cut rather than dropping it silently.
  - `u` means "you run it" / "you do it" (carry out the just-suggested command, script, or action yourself instead of expecting the user to)
  - `c`, `cm`, `commit` mean "commit" (invoke the `commit` skill), unless the previous message offered `[c]` for something else, in which case `c` picks that bracket-prefix option instead.
  - `🚢` means "ship it" (land the work)
- `<N> iter` means "option N is the front-runner, but iterate on it": treat N as the starting point and propose refinements rather than committing it as-is. E.g. `2 iter` → improve on option 2.

## Shorthand

- Interpret these tokens as shorthand for the named referent when they appear inside a user message (not as a whole reply). These are **input-only**: expand them when reading user input, and always write the full word ("clipboard", "root", "spreadsheet", "worktree") in own output. Never echo the shorthand back in status updates, prose, or commit messages.
  - `cb` means "clipboard"
  - `r` means "root" (the main checkout, vs. a worktree)
  - `trix` means "spreadsheet"
  - `wt` means "worktree"

## Output

- Never use em dashes (—) in any output, code, comments, commit messages, or PR descriptions. Use a comma, parentheses, semicolon, or two sentences instead.
- Write for the human who'll read it, not for yourself or an AI: PR titles/descriptions/comments, commit messages, and person-to-person comms all reach someone who may not share your context. Prefer the term that lands fastest for that reader (the common everyday word) over the technically-precise, formal, or insider one.
- Never emit `cb`, `r`, `trix`, or `wt` as standalone tokens in own output; always expand to "clipboard" / "root" / "spreadsheet" / "worktree". These are input-only shorthand (see the Shorthand section above) and reading them back as jargon obscures meaning.
- Spell out niche or insider technical acronyms in prose rather than abbreviating: write "infrastructure as code", not "IaC". Keep only acronyms a reader skims without expansion (API, AWS, URL, PR). Pre-send check: scan output for all-caps tokens of 2+ letters; each must be whitelisted or spelled out.
- When offering the user a choice between alternatives (commit messages, refactor approaches, naming options, phrasing variants, follow-up actions), present them as a numbered list. Numbers must be globally unique across the whole response: if a reply has multiple groups of choices, number sequentially across all of them (1-3 in section A, 4-6 in section B), never restart at 1 per section. Aim for ≤9 total items so each stays a single digit; fall back to digit+letter only when more are truly needed. Does not apply to step-by-step instructions or enumerations that aren't choices.
- When a choice is *visual* (colors, ANSI styling, layout, formatting, rendering variants, anything the user judges by appearance), each option MUST include a concretely rendered sample, never just a prose description like "orange background, black text". This applies to numbered chat choices AND to `AskUserQuestion` options. The question tool's option label/description fields can't render ANSI, so when the visual is ANSI-only, emit the rendered samples in a numbered list in chat text (one rendered artifact per line, stacked) BEFORE or INSTEAD OF calling `AskUserQuestion`, and let the user reply with the number. Describing the difference in words and expecting the user to mentally render it forces a wasted round-trip.
- When a numbered choice option ends in `: <rendered example>` (sample line, code snippet, prompt phrasing, anything the user compares visually), break after the `:` so the rendered artifact starts on its own line at the same indent across options. The artifacts then stack vertically and the user can diff them top-to-bottom instead of hunting them out of wrapped prose. Skip when the artifact is a single short token that already fits inline without wrapping, or when the choice is purely semantic with no rendered artifact.
- When one row in an option list is the live or currently-applied state, prefix it with a thin arrow `→` and indent the rest with two spaces so the numbers line up; render in a fenced code block to hold the alignment. `→` marks "you are here" and stays lighter than a bullet or emoji marker. Rendered example:

  ```
  → 1. Slate gray #666 (applied)
    2. Light gray #999
    3. Silver #ccc
  ```
- Chat color palette by surface: inline prose has three accents (plain inline-code, bold-inline-code per the bracket-prefix trick, link blue); fenced code blocks get the full syntax-highlight palette of the chosen lexer; status line bypasses markdown and supports full ANSI (8/256/truecolor). When asked about chat colors, distinguish the surface before claiming a limit, and reach for a fenced block when multi-color is needed and prose-inline isn't. Rendered example, file:line in a `python` fence so `42` shows in number-color:

  ```python
  src/foo.py:42
  ```
- When citing a line, keep the clickable `file_path:line_number` reference inline *and* quote the line's content (or the relevant clause) as a blockquote beneath it, so the citation is self-contained and the reader needn't open the file. A bare line number forces the reader to go look it up; they can't see the file you're reading from. Rendered example:
  > Got the exact clause (`file.py:42`). The existing rule only offers uppercasing the ambiguous letter.
  > > Uppercase the bracket letter only when it's visually ambiguous in lowercase: `l`, `I`, `o`.
- For bracket-prefix choice asks (a question offering options for a one-token reply, not a full numbered list):
  - **Layout:** stack the question stem on its own line and each option indented on its own line beneath it, even a binary. Rendered example:
    > Want me to commit this as a
    >   **`[f]ollow-up`**, or
    >   **`[a]mend`** the previous commit?

    Keep the stem free of a bare ` or ` enumeration of the choices: either end it before the options (as above, where ` or ` sits on a bracketed line) or make it a neutral question (`How should I handle this?`). Re-stating the choices in the stem (`Want me to commit, or land it?`) is redundant with the brackets below and trips the `check_bracket_prefix.sh` stop hook, which reads the stem line in isolation.
  - **Bracket every option, no exceptions:** wrap the whole option (bracket prefix + remainder) in a single bold inline-code span so the brackets, inner letter(s), and remainder share one color and weight. Source form is `**` + `` ` `` + `[` + letter(s) + `]` + remainder + `` ` `` + `**`.
  - **Reply:** accept the bracketed prefix (case-insensitive) as a complete reply and map it back to the full option.
  - **On letter collisions:** prefer the single-letter prefix; extend to multi-character (rendered **`[am]end`** vs **`[ad]d`**) only when two options would otherwise share the same letter. Case never disambiguates, since matching is case-insensitive: **`[d]iff`** vs **`[D]iff+args`** both map to `d` and the second is unpickable, so go multi-character instead (e.g. **`[de]xact`** vs **`[da]rgs`**).
  - **On casing:** purely a readability choice on the letter itself. Uppercase only when the letter is visually ambiguous in lowercase (`l` looks like `1`, `I` looks like `l`, `o` looks like `0`); unambiguous letters stay lowercase. So **`[c]ommit`** and **`[L]and`** in the same prompt is correct (mixed casing on purpose), not **`[C]ommit`** + **`[L]and`**.
  - **No competing label scheme:** the bracket letter is the option's *only* label. Don't also enumerate options with `A.`/`B.` or `1.`/`2.` (e.g. `A. … [s]pine-only` + `B. … [a]bsorb`): the `A.` label reads as the accept token for the `[a]`-prefixed option even when that's the *second* entry. For block-layout options (directory trees, diagrams, code), lead each block with its bracketed name on its own line, no enumeration.
  - **Pre-send checklist**, run on every question before sending:
    1. Does the question offer alternatives the user picks between? Check for `or` anywhere, **including inside parentheticals** ("Want me to add it (to global, or to project)?" is ternary: global / project / neither). When the proceed-as-proposed branch is one of the alternatives, label it with a concrete verb and its own prefix ("Proceed as proposed, or split, or skip?" → **`[p]roceed`** / **`[sp]lit`** / **`[sk]ip`**); don't hide it behind a vague affirmative stem ("Sound right, or split, or skip?").
    2. Count the alternatives, including an implicit "neither/no" if the outer frame is a yes/no with embedded options.
    3. Verify each alternative is wrapped as `**` + `` ` `` + `[x]remainder` + `` ` `` + `**`.
    4. Scan the bracketed letters across all options, case-insensitively (matching is case-insensitive, so `[d]` and `[D]` are the same letter and still collide); if any two share the same letter, extend both to multi-character per the `[am]end` vs `[ad]d` rule (e.g. `[sp]lit` vs `[sk]ip`, not `[s]plit` vs `[s]kip`, and not `[d]iff` vs `[D]iff+args`).
    5. An alternative that names a command, tool, slash-command, or keyword (e.g. "land with `worktree-done`") still needs its own bracketed letter; the keyword does not double as the accept token.
    6. If any alternative lacks `[` … `]`, fix before sending.
    7. Does any option carry a second label (`A.`/`B.`, `1.`/`2.`) beside its bracket prefix? Strip it, the bracket letter is the only label.
- When an own `[c]ommit` follow-up offer is accepted (reply `c`/`cm`/`commit`/🚢 mapped to the commit option), invoke the `commit` skill via the `Skill` tool rather than running `git commit -m "<self-chosen subject>"` directly. The skill drafts numbered subject options for the user to pick; auto-picking bypasses that choice. Same rule for any other phrasing where the offered action was "commit" (e.g. "want me to commit?"). To commit without the skill, the user has to opt in explicitly.
- When offering a worktree follow-up, present three separate bracket-prefix options (never bundled as **`[c]ommit and land`**):
  - **`[c]ommit`**: commit, stay in the worktree.
  - **`[p]romote`**: commit + fast-forward the default branch to here, keep the worktree (via `worktree-promote`).
  - **`[L]and`**: commit + `worktree-done`, which also tears the worktree down.

  Bundling forces both actions when the user often wants just to checkpoint; promote and land share the fast-forward but only land removes the worktree. When **`[L]and`** is among the options, append a trailing ` 🏁` after the closing `?` to flag that picking Land completes the objective; since Land is the last option, the 🏁 sits right after it (`[L]and (...)? 🏁`).
- Lead key sentences with a category emoji so the user can scan responses at a glance. Exactly one space after the emoji, then the sentence. The ⏺ message marker is rendered by Claude Code; the emoji goes immediately after it inside the message text. Categories:
  - 🔍 active exploration / reading / searching (before the answer is in hand): `🔍 Grepping for callers of `do_thing` across the repo.`
  - 🕵 finding / result / "turns out" (after the search lands): `🕵 Found it. The cause is in script.py:42.`
  - 🛠️ action / intent ("Let me...", "I'll..."): `🛠️ Let me work from a worktree.`
  - 🛬 land / ship / merge: `🛬 Landing branch foo into master.`
  - 👉 question to user / need clarification: `👉 Should this also rebase, or just fast-forward?` Fires only when the sentence asks for a reply. An acknowledgment opener (`Good catch.` → 🧠, `Got it.` → 💡) and an action opener (`Let me check...`, `I'll...` → 🛠️) are never 👉, even when a tool call follows; never collapse a `🧠 Good catch. 🛠️ Let me check...` pair under one 👉.
  - 💡 acknowledging a user's good idea or suggestion: `💡 Good idea, that's a cleaner phrasing.`
  - 🧠 user is right / good catch / smart call: `🧠 Good catch, that's the actual bug.`
  - 💅 cosmetic nit / optional polish (harmless, fine either way, not 🔴): `💅 Two spaces before the `\`; a single one is tidier.`
  - 🔴 warning / blocker / caveat (defensive, not yet broken): `🔴 Lockfile changed; skipping auto-stash.`
  - 💥 hard failure / error (something broke): `💥 Tests failed: 3 of 47 assertions did not pass.`
  - 🟢 step succeeded (intermediate success): `🟢 Tests pass, ready to land.`
  - ✅ success: the overall task or work verified and succeeded, not the session-done signal: `✅ All tests green, change works end to end.`
  - 🏁 objective complete (the session-done signal already used in Workflow): `🏁 Worktree landed, branch deleted.` Follow it with a checklist, per the convention below.

  Use sparingly: only prefix sentences that genuinely belong to one of these categories. Plain prose, code explanations, and tool-call narration stay unprefixed.

  **Stacking in one message:** the emoji attaches per key *sentence*, not per message, so one message often stacks several, each leading its own line. The common shape is a result line then a question line, two prefixes, not one:
    - `🟢 Done; the rule reads cleanly now.`
    - `👉 Commit this in the worktree?`

  The trailing ask keeps its own 👉 even as the closing line, since it's the part needing a reply; never let the opener's emoji stand in for it.

  **🏁 checklist convention:** always follow the 🏁 line with a checklist (one bullet per step that actually happened), so the completion is self-verifying instead of one easily-under-reported sentence. Each bullet leads with the marker matching its state:
    - ✅ a step that completed.
    - ⏸️ a step intentionally left ongoing (e.g. `⏸️ Worktree kept (fix-foo) for continued work` on a promote).

    For a worktree land/promote, the steps in lifecycle order:
    - committed (N commits);
    - promoted to master (fast-forwarded `old..new`);
    - pushed to `<remote>`;
    - worktree torn down (✅) or kept (⏸️, for promote);
    - branch `<name>` deleted.

    List only the steps that fired; for other objectives use whatever steps composed the work.
