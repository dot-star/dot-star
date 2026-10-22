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
  -
  -
-
-
-
  -
  -
  -
- The `.md` is what gets loaded and run against the work, so it stays short enough to scan; the why behind a rule is what a human reviewer (or a later edit) needs when judging whether the rule still holds. Inlined, it would bloat the `.md`. Keeping it on the same line number makes the lookup mechanical: open both files side by side and line N explains line N, with no anchors or cross-references to rot. Stated by the user on Thu, Oct 22.
  - Creating on first touch rather than backfilling every doc at once spreads the cost across edits that already have the context in hand. Backfilling cold would mean inventing reasoning for rules nobody is looking at, much of it inferred. Chosen by the user on Thu, Oct 22 (going forward only).
  - A matching shape is what keeps the side-by-side read aligned: if the `.meta.md` loses a line or a nesting level, every line after it explains the wrong rule. Keeping the markers even on an empty line keeps the `.meta.md` renderable as the same outline, so a reader skimming the `.meta.md` sees the `.md`'s structure. A blank stays blank because prose on a blank `.md` line would explain nothing and would merge paragraphs in the rendered `.meta.md`.
  - The `.md` is trimmed on purpose, so the `.meta.md` is where the cut material goes; no length cap there means trimming the `.md` never costs the reasoning. Only lines the edit touches need reasoning, matching the going-forward choice above.
  - The first draft covered every `.md` minus a deny-list, which reached too far: Claude edits markdown in repos that never chose this convention, and a README there would sprout a `README.meta.md`. Some directories also load every `.md` they hold, so `commands/commit.meta.md` would register a `/commit.meta` slash command. An allow-list of the instruction-doc locations avoids both and the files the deny-list named (memory files indexed by their own frontmatter, todo lists churning by the hour, throwaway plans and scratch) fall outside it for free. A meta of a meta would recurse forever. Scope narrowed by the user on Thu, Oct 22.
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


