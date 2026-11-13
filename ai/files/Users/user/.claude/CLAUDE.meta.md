# User preferences

## Principles

-
-
  -
    -
      -
      -
      - Moving the last line of a chain hands its `;` to the neighbor, so a one-line move diffs as two rewritten lines.
    - A diff-size trigger alone misses the outgrown name: renaming a function the feature now routes a new case through shrinks nothing, so it passes as polish and lands after the feature, which then ships under a name that already lies.
    -
    -
    - A pure move out of a personal repo publishes the known-broken version first, then a fix for a bug that was never this repo's own; the split only pays off when the reader can check the no-op against the original, which needs the original in the same history.
-
-
-
-
-
  -
  -
  -
- Naming the source carries the rule past bugs: a warning silenced in config or output corrected by hand is the same patch in another form; the problem returns on the next run.
  -
  -
  -
  -
  -
  -
-
  -
-
  -
  -
- An expected outcome costs the reader a read and tells them nothing they didn't already assume; the work still runs, only the report of it is dropped.
  - A passing check is the commonest case of an expected outcome reported anyway.
-
-
-
-
  -
  - An empty `grep --recursive` over `ai/contexts/` once reported a term appeared nowhere, so the reply said the docs needed no change, while the symlinked personal docs used it in a dozen places. That miss is silent: its output looks like a true absence, so only a scope check catches it.
-
-
-
  -
  -

## Supplemental preferences

-
  -

## Workflow

- A handoff costs the user a context switch: they copy, paste, open a terminal, then relay the result back. This session loses sight of the outcome too. Rules that describe how to hand off read as permission to, so without a stated default sessions reach for the handoff the moment one is described, even when a direct route was open.
-
-
  -
  -
  -
-
  -
  -
  -
  -
  - Repos ignore `.claude/worktrees/` because `EnterWorktree` writes there; a hand-picked path lands where no ignore rule covers it (a session in one repo once made `worktrees/<name>` in another), so every later status check lists it.
    - Most cross-repo edits are a line or two in a context doc, which this session can write directly at the absolute path; routing every one to another session turned a one-line fix into a terminal round trip. The other repo's `CLAUDE.md` never loaded here, so reading it is what keeps the edit inside that repo's conventions.
    - `EnterWorktree` creates only in the launch repo (or one nested inside it) and enters only those repos' worktrees. With the ban unscoped, a handoff was the only legal route to a worktree in another repo, so every multi-commit cross-repo fix became a terminal round trip the session could have skipped.
      - The ban exists to keep worktrees under the ignored `.claude/worktrees/`; the carve-out keeps that path, so the other repo's status stays clean and `wts` still finds it. The `worktree-` branch prefix matches the branches `EnterWorktree` names.
      - The other repo's `CLAUDE.md` never loaded here, so reading it is what keeps the edit inside that repo's conventions.
      - Nothing else cleans up a worktree this session made by hand: `ExitWorktree` only knows the ones `EnterWorktree` made.
    - A handoff costs a paste, a new terminal and a relay back, so it waits for the user to want a separate session. One paste opens that session already briefed, so the user never retypes or relays the context; a bare "start a session there" leaves them writing the brief. Reading the brief from a file sidesteps zsh quoting: the task text often holds quotes, backticks or `!`, any of which breaks an inline single-quoted prompt.
  -
  - Hammerspoon loads its modules from `~/.dot-star/tools/hammerspoon/` (`script/post_install.sh:331`), the main checkout, so a worktree edit can't run until `/try` ferries it over; every tweak-reload-look loop paid that round trip. Pending edits there flip the trade back: this session's change would mix with unreviewed work, so the worktree's isolation earns its cost again.
  -
    -
    -
    -
-
-
-
-
-
-
  -
  -
-
-
-
  -
  -
  - Close the session from a hook rather than asking for `/exit`: by the time `x` lands the user is done, so a manual exit (or Ctrl+D twice) is pure friction. The hook sends SIGTERM, which restores the terminal the same way Ctrl+D does but exits 143, so it first touches the marker `claude_run` exports; the wrapper then counts the kill as a clean finish and still minimizes and closes the tab.
  - The hook can't tell a finished close from a paused one: it only checks whether the mark exists when a reply ends. Reading `x` as "close" invites writing the mark first, but a bare `x` on a dirty tree routes the commit through the skill's pick list, and that pick ends the reply. Ordering is the only thing keeping the land whole, so the rule spells it out.
  -
  -
  -
- Hammerspoon is already installed and bootstrapped by this repo, so a hotkey or automation there costs one Lua file. Left off the list, an answer reaches for heavier options (a third-party app, a Shortcuts workflow, a launchd job) and skips the one already in place.

## Shell commands

-
-
  -
  -
  -
  -
-
-

  ```




  ```
-
  -
  -
-
  -
  -
- IPython colorizes its output and tracebacks, which pays off on every run the user watches, not only an interactive session. Commands Claude runs itself aren't suggestions, so they stay out of scope.
-
-
  -
  -
  -

## Writing style

-
-
  -
  -
  -
    - A bare `Mark` opens a noun phrase (a mark, the mark), so it stays on the bad list, but `Mark <todo> done` reads fine: it frames the commit as finishing something, where checking a todo off only names the checkbox. Scoping the exception to that one form keeps it from reopening `Mark` as a general leader.
  -
  -
-
-
-
  -
  -
  -
- The `.md` is what gets loaded and run against the work, so it stays short enough to scan; the why behind a rule is what a human reviewer (or a later edit) needs when judging whether the rule still holds. Inlined, it would bloat the `.md`. Keeping it on the same line number makes the lookup mechanical: open both files side by side and line N explains line N, with no anchors or cross-references to rot.
  - Creating on first touch rather than backfilling every doc at once spreads the cost across edits that already have the context in hand. Backfilling cold would mean inventing reasoning for rules nobody is looking at, much of it inferred.
    - Folded into the change, the companion's first appearance is a file of hundreds of bare markers with the few reasoning lines buried somewhere inside, so a reviewer can't see which rules the change explains. The skeleton is the same move as the refactor-first split in Principles: the scaffold commit is verifiably empty of claims, and the change then diffs as one reasoning line per doc line it touches. A brand-new doc has nothing to scaffold ahead of it, so the split would only add a commit.
  - A matching shape is what keeps the side-by-side read aligned: if the `.meta.md` loses a line or a nesting level, every line after it explains the wrong rule. Keeping the markers even on an empty line keeps the `.meta.md` renderable as the same outline, so a reader skimming the `.meta.md` sees the `.md`'s structure. A blank stays blank because prose on a blank `.md` line would explain nothing and would merge paragraphs in the rendered `.meta.md`.
  - The `.md` is trimmed on purpose, so the `.meta.md` is where the cut material goes; no length cap there means trimming the `.md` never costs the reasoning. Optional because a required line gets filled anyway: with no real why in hand it turns into filler or a guess that reads as settled. A bare marker keeps the alignment and claims nothing.
  - A credit adds no information: every line in these docs is the user's rule, so crediting it to the user is true of every line, and git history already records when a line changed.
  - The first draft covered every `.md` minus a deny-list, which reached too far: Claude edits markdown in repos that never chose this convention, and a README there would sprout a `README.meta.md`. Some directories also load every `.md` they hold, so `commands/commit.meta.md` would register a `/commit.meta` slash command. An allow-list of the instruction-doc locations avoids both and the files the deny-list named (memory files indexed by their own frontmatter, todo lists churning by the hour, throwaway plans and scratch) fall outside it for free. A meta of a meta would recurse forever.
  - The hook makes the rule hard rather than remembered: a text-only rule slips the first time a session is busy. PostToolUse can only add context, not block, so it nudges right after the edit, the moment the `.meta.md` is cheapest to fix. The loader exclusion exists because `~/.claude/CLAUDE_*.md` is a glob: a `CLAUDE_foo.meta.md` would otherwise inject its reasoning into every session and push the payload past the 10KB hook cap. The mention hook globs `ai/contexts/*.md` the same way, and a `.meta.md` explaining a `claude-mention:` marker would quote that marker and become a mention target itself. The credit check rides in the same hook, since the `.meta.md` is open and cheapest to fix at that moment.
-
-
-
-
-
  -
  - Fixture ids don't read as illustrations, so the parent rule slid past them: a value copied from dev data looks like plain test data yet names a real customer.
  - A word from the triggering source feels invented because it's already generic-sounding and fresh in mind, so the parent rule's "real data" test slides past it; checking where the word came from catches what checking how it sounds misses.

## Styles





-
-
-
-
-
-

## Input

-

  The prompt-time hook matches a whole-message token only when it fills the prompt or a `;` clause, so a mid-sentence use injects nothing; the index keeps every token in view so Claude knows to look it up.





-
  -
  -

## Output

-
  -
  -
  -





-
-
-
- Output gets read or pasted as-is, so `&lt;name&gt;` reaches the reader as junk; square brackets survive markdown and still read as a slot.
-
  -
  -
  -
  -
  -
  -
-
-
  - The word sounds alarming and makes the event seem worse than it was; naming the mechanism tells the reader what happened without that alarm.
- Scoping the rule to prose left menu rows outside it, so a trimmed menu parenthetical shrank a commit to its bare hash right where the reader decides what to do with it.
  -
  - A hash looks like the short handle the trim rule keeps, but the subject is the only part a reader recognizes, so trimming it cuts the load-bearing words.
  -
  -
-
  -
  -
- A reader counts the keys in a chord by counting the names, so every extra name adds a phantom key. The spelled-out word lands fastest, since not every reader knows the key glyphs by sight. A glyph printed on the keycap helps the reader find the key, so it rides along in parentheses without counting as a key of its own; a glyph the keyboard never shows (Shift, Return, the arrows) gives them nothing to match.
  - Parentheses mark the glyph as a gloss on the word; set side by side with only a space, the glyph and the word parse as two keys.
  -
  -
  - A stack of long chords is where the form is most tempting to shortcut, so the example shows it holding up at length: every key named once, glyphs only where the keycap prints one.

    ```

    -
    -
    -
    ```
-
  -
  - A direction word is a pronoun for a place: it binds to whichever party the reader stands in. It bites wherever something moves between two parties, since the same flow is incoming to one and outgoing to the other.
  -
  -
  -
  -
  -
  -
  -
  -
  -
-
  -
  -
  -
    -
    -
    -
-
  -
-
  -
  -
-
  -
  -
-
  -
  -
-
  - A list of six decisions holding options numbered 1-13 made `6` mean two things and the suggested reply `1 4 6 8 10 12` mixed both levels.
-
  -
  -
- A "both" option looks like strictly more for no extra price, which makes it the reflexive pick even when the two halves overlap, conflict or double the review. Naming the cost turns it back into a real tradeoff the user weighs against the single options; naming the gain too keeps that tradeoff balanced, since the case for both isn't always just "more" (the halves may cover different failures, or one may only be safe with the other). Stating both inside the option keeps them beside the pick instead of in prose the reader skips on the way to the list.
-
  -
  -
-
  -
  -
  -
-
-
  -
  -
  -
    -
    -
  -
  -



  ````




  ```

  ```
  　 -
  　 -
  ````
-
  -
  -



  ```

    2.
    3.
  ```
-
  -
  -
  -
  - Most readers skim, so a version that hits weaker on the first pass never gets its point across, however precise it is. Precision a reader needs can go in a later sentence; a punchline split by an aside can't be repaired later.



  ```

    2.
    3.
  ```
-

  ```



  ```
-

  ```
  1.
  2.
     -
  3.
  ```
-
  -
  -



  ```
  1.


  2.


        -
  ```
-

  ```

  ```
-
  >
  > >
-
-
-
  -
    >
    >
    >


  -
  -
  -
  -
  -
  -
  -
    -
    -
    -
  -
  -
    1.
    2.
       -
    3.
    4.
    5.
    6.
    7.
    8.
    9.
    10.
    11. Mirrors item 9: the versions rule stood alone outside this list, so it got applied only when remembered and the row went missing from messages that laid out candidate edits.
-
  - A `!` command's output lands in the conversation, so Claude can verify the result (a deploy landed, a test passed) without the user pasting it back; a new terminal hides the run and turns the check into a round trip. A `!` command runs with no keyboard attached, so a `read` prompt, password ask or full-screen program gets nothing and silently skips or hangs, and a command that never exits would pin the session's prompt.
    - A confirmation prompt guarding a dry run exists only so a human reviews the dry run. Once the user has reviewed it in the conversation, the prompt has done its job, and answering it ahead of time keeps the run visible instead of exiling it to a terminal just to type one letter.
  -
  -
    - Most blocks target the command's shape, not its goal: a shell redirect where `Write` is allowlisted, a `cd` prefix or a pipeline that drags an allowlisted command into a prompt. Reshaping the call finishes the work in-session; jumping to the script on the first block hands the user a paste for work this session could have done.
    -
    -
  -
    -
  -
    -
    -
    -
  - The user copies other things between turns, so a copy from an earlier turn may be gone; a claim made from memory of the `pbcopy` sends them to paste the wrong thing. Copying again on a mismatch makes the claim true rather than only checked.
  -
  -
  -
-
  -
  -
  -
  -
-
  -
  -
    -
    -
    -
-
  -
  -
  -
- A partial read looks like a full one: the subject-draft tree shape sits past the first few thousand bytes, so a capped read misses it and the menu gets drafts in a fence, missing their `[cN]` tokens and tree glyphs.
-





    1.
    2.
    3.
    4. Fix at the source applies to menus too: a cause the session could fix is in scope now, so it gets an accept token rather than only a todo.
    5.
    6.



  A wide row label shifts every parenthetical, so the extension names both sides explicitly rather than leaving the collision rule to catch it.





  A lone ⚡ row either bundles both fixes or leaves the cause to 📋, so the source fix never gets a do-it token of its own.











  >
  >
  >
  >
  >
  >
  >



  >
  >
  >
  >
-
-
-
-
  -
  -
  -
  -
  -
  -
  -
  -
  -
  -
  -
  - A step an earlier turn already ran costs the reader nothing, yet "a step skipped" in the 🔴 line reads as matching it; a calm marker of its own keeps an already-banked commit from flashing a bright red alarm.
  -
  - Narrowed from "a step skipped" to a needed step left undone: a step skipped because it already happened is the 💾 case above, and a red alert over it trains the reader to ignore 🔴.
  -
  -
  -
  -




    -
    -




    -
    -
    -
    -


