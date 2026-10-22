# User preferences

## Principles

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
  - The `.md` is trimmed on purpose, so the `.meta.md` is where the cut material goes; no length cap there means trimming the `.md` never costs the reasoning. Only lines the edit touches need reasoning, matching the going-forward choice above.
  - The first draft covered every `.md` minus a deny-list, which reached too far: Claude edits markdown in repos that never chose this convention, and a README there would sprout a `README.meta.md`. Some directories also load every `.md` they hold, so `commands/commit.meta.md` would register a `/commit.meta` slash command. An allow-list of the instruction-doc locations avoids both and the files the deny-list named (memory files indexed by their own frontmatter, todo lists churning by the hour, throwaway plans and scratch) fall outside it for free. A meta of a meta would recurse forever.
  - The hook makes the rule hard rather than remembered: a text-only rule slips the first time a session is busy. PostToolUse can only add context, not block, so it nudges right after the edit, the moment the `.meta.md` is cheapest to fix. The loader exclusion exists because `~/.claude/CLAUDE_*.md` is a glob: a `CLAUDE_foo.meta.md` would otherwise inject its reasoning into every session and push the payload past the 10KB hook cap. The mention hook globs `ai/contexts/*.md` the same way, and a `.meta.md` explaining a `claude-mention:` marker would quote that marker and become a mention target itself.
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


