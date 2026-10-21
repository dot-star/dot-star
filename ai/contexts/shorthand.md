# Shorthand

Loaded on demand: the `inject_shorthand_meaning.py` hook matches every prompt against this file and injects the entry it matches, so add or edit a token here, never in `~/.claude/CLAUDE.md`. Section names below (Workflow, Output, the bracket-prefix list) refer to that file.

The hook reads each top-level entry's backticked tokens, up to its `mean` or `means`, as the patterns to match.

- Read `<N>` as a number and any other `<...>` as free text.
- Add a `<!-- shorthand-match: <regex> -->` line inside an entry for a form its tokens can't spell (a reversed `3c`, a trailing `iter`).

## Whole-message tokens

Interpret a bare one-token reply or a short fixed phrase as shorthand. Fires only when the entire message is exactly that token or phrase; if the message starts with a question word (what/how/why/is/should/can/does/...) it's a question *about* the token, not an invocation. A bracket-prefix offer in the previous message outranks this table, per Input in `~/.claude/CLAUDE.md`.

- `y`, `ya` mean "yes" (treat as a `y/n?` style answer)
- `n`, `no`, `nope` mean "no"
- `res` means "resume"
- `cont` means "continue"
- `re` means "retry"
- `refix`, `confix` mean "rebase onto the default branch and fix conflicts"
- `s`, `st`, `sta` mean "give me a status, written for someone with no context":
  - Open with one line naming what we're trying to get done, then one numbered item per entry stacked vertically, each led by a status emoji after its number, per the numbered-findings rule in Output.
  - Cut detail before cutting the orientation; keep the whole thing scannable at a glance.
  - Don't start new work.
  - Close on where the work sits, one label per line.

  The markers:

  ```
  ✅ done
  🛠️ in flight
  📋 pending
  ```

  The labels below are the usual ones, not the whole set: omit any that don't apply and add anything else worth mentioning:

  ```
  worktree: <name>
  branch:   <name>
  dirty:    <file count, or "clean">
  ```

  A status is a place to act from, so end it on the bracket-prefix menu that applies (worktree menu, loose-end rows, an open pick), rendered in full per the Output rules; with nothing to offer, end on the labels.

- `ses`, `sesid`, `sess`, `sessid`, `sid` mean "print this session's handle as other sessions see it and put it on the clipboard": run `ListAgents` and copy the name and bracket ref from its `This session is` line, wrapped in a label that says what they are (`Peer Claude session dot-star-12 [abcdef] (reach it with SendMessage):`).
  - Label the handle so it explains itself wherever it lands: pasted into another session ahead of a task, a bare `dot-star-12 [abcdef]` reads as a hostname, branch or user, so the receiver misses that the task is about a peer session.
  - Copy the ref along with the name: two sessions can share a name, and the ref is what `SendMessage` uses to tell them apart.
  - Print the full id (as in the scratchpad path) beneath it, labeled, without copying it. A peer can't look that id up, since the session list shows only short refs and the ref isn't a prefix of the id.
- `2g`, `2nd` mean "summarize this session so far for a second opinion and put the summary on the clipboard": the reader is another model seeing only the pasted text, so write it for someone with none of the session's context. It's a handoff, so don't start new work.
- `md`, `mds` mean "map the instruction docs loaded in this session": render a `flow` diagram from each context channel down to the files it delivered. It's a read, so don't start new work.
  - Group by channel: native memory (global `CLAUDE.md`, the project `CLAUDE.md`, any `CLAUDE.local.md` and its `@` imports, `MEMORY.md`), each `SessionStart` loader call with its `CLAUDE_*.md` files in load order, and fired `claude-mention` pointers.
  - Give each file its absolute path (the real dot-star path where it's a symlink) and its size, plus each loader call's total against the 10,000-character cap.
  - Flag a loader call near the cap, a file offloaded to a preview, or an `@` import or symlink that failed to resolve.
- `todo`, `todos` mean "list the open todos for the repo we're in": find the file the way `~/.dot-star/ai/contexts/todo-banking.md` resolves where entries land (personal record first, then the markdown beside the work, then the repository root), then render them for scanning. It's a read, so don't start new work.
  - Name the file in a lead line above the list.
  - Order by the file's own pick rule when it states one, else priority then severity.
  - Render one row per entry in a fenced block: a row number, then labels (`P2 S3`), then the entry's first line trimmed to a subject.
  - Number the rows `1`, `2`, `3` in rendered order, so a bare-number reply picks that entry without describing it. Numbers are positional and hold only for this render, since banking or closing an entry shifts them.
  - Mark the row the pick rule takes next with `❯` (the recommended-pick rule in Output).
- `bank`, `bt` mean "bank todo" (or "bank task"): bank the loose ends the conversation just named as todos, per the banking rule in Output and `~/.dot-star/ai/contexts/todo-banking.md`.
- `cbank` means "bank a consideration": bank the point the conversation just raised as a todo whose task is to consider it, not to carry it out, per `bank`. Lead the entry with `Consider` (`Consider moving the cache into the loader`), so whoever picks it up weighs the idea and decides rather than implementing it.
- `eg`, `egs`, `examples` mean "show me examples"
- `play` means "play it out": simulate how the situation under discussion unfolds from here, turn by turn. Voice the other side's likely moves (a reviewer's pushback, a script's output, a user's next click) and show my best move after each one. Branch wherever a realistic alternative splits the path. It's a rehearsal, so don't send, write or run anything.
- `sample`, `val`, `validate` mean "render a worked example of what we just changed, as it would fire in practice, so I can check it does what I meant": pick a realistic input (this session, where it fits), show the output the change produces, then name what's new against the old behavior. `show` renders the edit itself; `sample` renders what the edit produces. It's a preview, so don't start new work.
- `opt`, `opts` mean "show me options"
- `show`, `show me` mean "render the thing the previous message described as its actual artifact": the literal file lines, sample output, or rendered text, so I can evaluate it rather than read another description of it. It's a preview request, so don't write the file or run the action until I say so.
- `flow`, `ascii`, `ascii flow` mean "render the thing under discussion (a pipeline, control flow, data flow, architecture) as a text diagram with boxes and arrows, using box-drawing and tree-branch glyphs (`└─` `├─` `│` `→`) where they read cleaner than plain ASCII (`+` `-` `|`)"
- `tl`, `timeline` mean "render the events under discussion as a timeline table": one row per event, oldest first, each showing the gap from the row above. A channel style doc may specialize the layout.
- `defend`, `prove` mean "defend/prove the prior reply" (justify each claim or item in it)
- `w`, `weigh` mean "weigh the options the previous message numbered and pick one": a table with one row per criterion and one column per option, each cell led by `✓` or `✗` plus a few-word qualifier, then a `❯` on the pick with the deciding reason. The grid lets the reader compare options across a row at a glance, where a gains/costs paragraph per option makes them diff two blocks of prose. It's a judgment, so don't edit anything. Trailing numbers narrow the field (`w 2 4` weighs only options 2 and 4).
  <!-- shorthand-match: ^w( \d+)+$ -->
- `harden`, `bake`, `firm` mean "strengthen the rule i just hit" by tightening it in `CLAUDE.md` or the matching `CLAUDE_*.md` sibling, or promoting it there from memory if that's where it lives. Memory isn't durable enough to harden into.
- `cod`, `codify` mean "codify the rule" (invoke the `codify` skill): promote a saved memory into a mechanism that fires on its own (a hook, `settings.json` entry, `CLAUDE_*.md` line, shell alias, or skill).
- `t`, `trim` mean "strip whatever we're working on (a comment, a sentence, a rule, a block of code) to its load-bearing parts": cut non-load-bearing content outright (niceties, rationale, cross-references already obvious from context), not just tighten the wording, while preserving every constraint; flag anything load-bearing that can't be cut rather than dropping it silently.
- `ws` means "add whitespace for readability": reformat whatever we're working on (a doc, code, a comment, a rule) with blank lines between stanzas and sub-bullets for dense lists so it scans better, without changing the content.
- `vws` means `ws` weighted vertical: reach for blank lines first and add sub-bullets only where spacing alone leaves the block dense. Match the surrounding list's density, though: where the neighboring bullets sit tight, the block stays tight too, sub-bullets included.
- `gen`, `generalize`, `neu`, `neutral` mean "generalize the examples": when an example carries my real pasted content (a commit message, path, value), swap it for a neutral placeholder showing the same pattern.
- `u` means "you run it" / "you do it" (carry out the just-suggested command, script, or action yourself instead of expecting the user to)
- `c`, `cm`, `commit` mean "commit" (invoke the `commit` skill).
- `c<N>` (e.g. `c2`) means "commit with subject draft N": the worktree menu lists its drafted subjects under the commit row as `[c1]`, `[c2]`, `[c3]` (see the worktree menu rule in Output), and the number names one.
  - The pick is already made, so the commit runs with that subject verbatim and skips the skill's draft-and-pick step.
  - Accept the number first too: `3c` picks the same draft as `c3`. The reversal holds for every draft token (`3f`, `3p`, `3L`, `3x`), since the letter and number together name one row whichever leads.
  - One `c<N>` picks one commit: the number names a draft under exactly one commit's tree, so with two or more commits pending (one per repo, say) the reply names one per commit (`c2 c5`). A reply that covers only some of them commits those alone; the rest stay unpicked and get their trees re-offered.
  - `p<N>` and `L<N>` pick the same draft N from the commit row's list (the promote and land rows carry only a `[pN] ...` stand-in), then promote or land.
  - `f<N>` picks from the fold row's own list instead, since a fold's subjects describe the combined diff rather than the pending change alone, then folds into the target commit with that subject. A bare `f` folds under the target's existing subject.
  - `c<N> iter` is the `<N> iter` form: refine draft N, no commit yet.
  <!-- shorthand-match: ^((c|f|p|l|x)\d+|\d+(c|f|p|l|x))( ((c|f|p|l|x)\d+|\d+(c|f|p|l|x)))*( iter)?$ -->
- `cs` means "commit only the already-staged changes": like `c` (the `commit` skill), but never auto-stage; if nothing is staged, stop.
- `🚢` means "ship it" (land the work)
- `split`, `sp`, `prs` mean "propose splitting the current change into separate PRs": offer the unsplit PR first, then a split into 2, into 3 and so on while each PR still carries one intent, with line counts beside every PR. It's a plan, so don't branch, commit or push.
  - Count from `git diff --numstat <merge-base>`, summing each file's adds and deletes into the PR that would carry it.
  - Write each option as a numbered choice: a one-line summary of the cut, then one indented line per PR with its subject, base, file count, `+adds` and `-deletes`.
  - Name each PR's base so standalone and stacked PRs read apart at a glance: `standalone` for a PR that merges on its own, `on 1` for one stacked on the option's first PR. A standalone PR reviews and merges independently, where a stack stalls every PR above the one held up in review.
  - Render the options in a fenced block and right-align the file count, `+adds` and `-deletes` into columns shared by every option, so the counts compare top to bottom.
  - Carry each option's totals on its summary line, summed over its PRs and aligned in the same columns.
  - Mark my pick with `❯` and say why in one line.
  - Prefer standalone: pick a cut whose PRs are all `standalone` whenever one keeps each PR to one intent. When only a stack does, name the dependency that forces it.
- `<N> iter` means "option N is the front-runner, but iterate on it": treat N as the starting point and propose refinements rather than committing it as-is. E.g. `2 iter` → improve on option 2.
- `<x> vs <y>` or `<x> v <y>`, as a whole message, means `w <x> vs <y>`. Treat a `vs` or `v` inside an ordinary question or sentence as prose; it fires only when the candidates and their separator make up the entire message.
- `exp <x>` means "explain `<x>`" without acting on it; re-offer any menu it came from.
- `h <x>` means "how do I `<x>`?": answer with the steps to do `<x>` without doing it yourself. The question is the request, so `u` is how to hand the doing over.
- `o <x>` means "omit `<x>`": cut `<x>` from whatever we're working on and leave the rest as it stands.
- `r <x>` means "replace `<x>`": swap `<x>` for an alternate word or phrasing in whatever we're working on and leave the rest as it stands.
- `show me <x>` means "render `<x>` concretely": `<x>` names something the last message described (a rule, an edit, an output line, an option); produce that artifact itself, not a summary of it. Same preview-only semantics as `show`.
- `w <x> vs <y>` or `w <x> v <y>` means "weigh `<x>` against `<y>`": the `w` judgment over candidates named in the message instead of numbered ones. Take any number of them (`w <x> vs <y> vs <z>`).

## In-message tokens

Interpret these tokens as shorthand for the named referent when they appear inside a user message (not as a whole reply). These are **input-only**: expand them when reading user input and always write the full word ("clipboard", "options", "root", "spreadsheet", "worktree") in own output. Never echo the shorthand back in status updates, prose, or commit messages.

- `c`, `cb` mean "clipboard" (e.g. "... to c", "... to cb"; a whole-reply `c` means commit)
- `nw`, `nwt` mean "no worktree": waives the isolated-worktree default (see Workflow).
- `opts` means "options": a request for numbered choices, answered per the numbered-choice rules in Output (e.g. "give me opts for the exit flow", "opts on naming"). Bare `opt` stays unmapped mid-message, since "opt in" and "opt out" are real phrases.
- `r` means "root" (the main checkout, vs. a worktree)
- `sta` means "give me a status": apply the `s`/`st`/`sta` entry under Whole-message tokens, even though other words surround it.
- `trix` means "spreadsheet"
- `wt` means "worktree"
