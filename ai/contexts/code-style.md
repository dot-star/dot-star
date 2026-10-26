# Code style

Loaded on demand: the Writing style section of `~/.claude/CLAUDE.md` points here before any code gets written, edited or reviewed. A principle quoted below ("touched code self-heals") lives in that file's Principles section.

- Never write single-line `if` statements; always put the body on its own line inside braces (write `if (cond) {` then `return x;` then `}`, not `if (cond) return x;`).
- When consecutive `if` statements each end in `return` (or `throw`), chain them as `else if` rather than leaving them as separate `if` blocks; this includes side-effecting actions (e.g. `if ! git rebase master`) where chaining is possible. Plain side-effect `if`s without a terminating return stay separate.
- Give each case its own branch: unpack a guard that folds several cases into one condition (`and`/`or`, a negated `not in (...)` membership) into an `if`/`elif` chain, one case per branch, each with its own `return`. The packed form makes the reader expand the boolean in their head to learn which inputs reach which outcome; the chain lists them.
  - Fail: `if record is not None and record.owner not in (None, caller): return None` then `return record`
  - Pass: `if record is None:` / `return None`, `elif record.owner is None:` / `return record`, `elif record.owner == caller:` / `return record`, then a bare `return None` for the rest
  - Write the chain on the first draft, never as a follow-up split after review; a condition that needs a comment to say which cases it covers is the tell.
- Prefer the most explicit form when it reads more plainly: an explicit `for` loop with an inner `if` and early `return` beats a compact `any(... for ...)` / comprehension when the loop makes the intent obvious. Readability over conciseness.
- Prefer spelling out the cases over a regex group when they're few and known: `deploy`, `deployed`, `deploying`, not `deploy(ed|ing)?`. A group or alternation packs several cases into one expression that's harder to read, diff, and reason about; reach for it only when the alternatives are open-ended or too many to enumerate.
- Make every concrete subclass state its own answer for a base-class hook; never let one inherit a silent no-op default. A subclass that never addresses the hook otherwise behaves as if it had chosen the default, with nothing marking the omission.
  - Raise `NotImplementedError` (or the language's equivalent) in the base, so a missing override fails loudly at the call site instead of quietly doing nothing.
  - Override with an explicit no-op body in each subclass whose honest answer is "nothing to do", carrying a comment that names why that case is exempt.
  - Write that no-op body as an explicit statement (`pass` in Python, `{}` where the language needs nothing), never a bare docstring or comment with no statement under it. A body that only documents itself reads as unfinished, so the next reader "finishes" it by raising, breaking every caller that relied on the no-op.
- Make every caller pass each argument; never give a parameter a default value. A default hides the choice at the call site: the reader can't see the value and a new caller inherits one it never weighed.
  - Fail: `def render(theme: str = "dark")` called as `render()`
  - Pass: `def render(theme: str)` called as `render(theme="dark")`
  - Keep a default only where it keeps existing call sites unchanged (a new parameter on a widely called function) or a library signature demands one; every new call site still passes the value explicitly.
- Two comment shapes:
  - **Block comments** (TODOs, design notes): blank line above and below.
  - **Line-doc comments** (describing the next line/pipeline): stay flush with the code they describe, no blank line between the comment and that code.
    - The "no blank line" applies only to the gap *below* the comment (comment-to-its-code).
    - A blank line *above* a line-doc comment is fine, and preferred, when it opens a new logical stanza, so the blank separates stanzas while the comment stays glued to its code below.
- Comments lead with WHAT (imperative verb + object) before WHY. Good: `# Strip geometry lines around each gitk run. The file is symlinked and gitk rewrites them on exit.` Bad (WHY first): `# gitk rewrites geometry lines on exit; strip them around each run so the symlinked config stays clean.` Bad (noun-phrase title, no verb): `# Vim swap files`; don't pattern-match local title-style comments, the new line ratchets to the imperative form per "touched code self-heals." The rule binds EVERY comment line, not just the first: each line of a multi-line comment, and each entry of a key→action or value→action mapping list, leads with its own imperative verb (`// Show fewer days with "-".`, not `// "-" fewer days.`). Before finishing any edit that adds or touches a comment, scan each new comment line and confirm its first word is an imperative verb; a continuation or list sub-line that fronts a key, value, or noun phrase is the common miss.
- Never restate a value in the comment documenting it. The comment carries the purpose and the tradeoff; the line below carries the value. Naming the current pick (`# Retry three times before giving up` above `max_retries = 3`) duplicates it in prose, so every retune drags a comment edit along and a skipped edit leaves the comment lying. Test it by imagining the other candidate values in that slot: if the comment has to change for any of them, it named the pick rather than the purpose.
- A comment carries what the code can't; anything recoverable from the lines below is noise. Cap a comment block at three lines of prose, about 30 words at standard wrap: past that it's explaining the domain rather than the line, so the explanation belongs in a doc or a commit body with the comment pointing there.
  - **Prose is what's capped.** A sample the reader scans rather than reads doesn't count: an example invocation, sample output, a column layout, a diagram. A 30-line before/after block costs a glance where four lines of explanation cost a paragraph's attention.
  - **The word figure is the backstop.** Three 150-character lines clear the line cap while carrying a paragraph, so a block busting 30 words is over however few lines it occupies.
  - **The test:** delete each sentence in turn, then ask whether a reader could recover it from the code below. Recoverable means cut, however well it reads.
  - **What survives:** a constraint invisible locally (why this call skips the flags its neighbor uses), the tradeoff behind a pick, the failure a guard prevents.
  - **What goes:** restating the mechanism the code already spells out, naming the platforms or commands a reader infers from the surrounding branch, the consequence of a consequence.
  - **Exempt:** a file-header or usage block, which documents the file rather than a statement. The cap governs a comment sitting over code.
- Build multi-line strings so the source mirrors the rendered output: one statement per output line, each carrying a literal newline, not several `\n` escapes packed into one long line. The split makes the rendered shape visible in the source and keeps diffs line-addressable. A `\n` mid-string is still fine (a header's trailing `\n\n` stays inline). Per-language idioms live in the matching style guide.
- Write a config-file list (TOML, YAML) one item per line, even a single item: the opening bracket ends the key's line, each item takes its own line with a trailing comma where the format allows one, and the closing bracket sits alone. Each item then diffs on its own line and adding one touches one line, the same reason a command's flags split one per line. A comment explaining an item goes inside the list, flush above that item, never above the key, so a second item can't strand it. Rendered example:

  ```
  extend-select = [
      # Require type annotations on every function; ty checks only what is annotated.
      "ANN",
  ]
  ```
- Pretty-print every JSON sample in markdown, even a two-key object: two-space indent, one key per line, keys in code-point order (`jq --sort-keys`), so adding a key diffs as one line. Rendered example:

  ```json
  {
    "bar": "baz",
    "foo": false
  }
  ```
