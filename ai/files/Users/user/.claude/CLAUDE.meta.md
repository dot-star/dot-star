# User preferences

## Principles

-
-
  - A diff-size trigger alone misses the outgrown name: renaming a function the feature now routes a new case through shrinks nothing, so it passes as polish and lands after the feature, which then ships under a name that already lies.
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
-
  -
  -

## Supplemental preferences

-
  -

## Workflow

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
    - Cross-repo edits are what tempt a hand-made worktree: `EnterWorktree` creates only in the launch repo (or one nested inside it). Routing the edit to a session in its own repo also loads that repo's `CLAUDE.md`.
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

## Styles





-
-
-
-
-
-

## Input

-





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
-
  - A `!` command's output lands in the conversation, so Claude can verify the result (a deploy landed, a test passed) without the user pasting it back; a new terminal hides the run and turns the check into a round trip. A `!` command runs with no keyboard attached, so a `read` prompt, password ask or full-screen program gets nothing and silently skips or hangs, and a command that never exits would pin the session's prompt.
    - A confirmation prompt guarding a dry run exists only so a human reviews the dry run. Once the user has reviewed it in the conversation, the prompt has done its job, and answering it ahead of time keeps the run visible instead of exiling it to a terminal just to type one letter.
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
-





    1.
    2.
    3.
    4.
    5.



















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


