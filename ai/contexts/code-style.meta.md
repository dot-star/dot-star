#



-
-
-
  -
  -
  -
-
-
-
  -
  -
  -
-
  -
  -
  -
- Lives here rather than in a Python style guide because keyword arguments read the same in every language that has them (Python, Kotlin, Swift, Ruby). Sits beside the no-defaults rule, whose Pass example already called by keyword without saying so; stating it outright makes the habit a rule instead of an inference from an example. "Each call you write" scopes it to new and touched call sites, per touched code self-heals, so untouched callers stay as they are.
  - A bare `True` is the case that hurts most: nothing at the call site says what it switches on.
  -
  - Names only the cases where a keyword is impossible, so "it fits on one line" or "the argument is obvious" never reads as an exemption.
-
  -
  - Leads with both gaps: a headline opening on "stay flush" and "no blank line" read as the whole rule, so the blank above got skipped.
    - Was "fine, and preferred, when it opens a new logical stanza", which left the blank to judgment and let comments land flush. Defaulting to always takes the call away.
      - Names the misreading the blank prevents, so the rule reads as grouping rather than cosmetics.
      - A comment opening a block or file has only the opener above it, so a blank there separates nothing.
      - Replays of a flush-neighbor edit left an untouched comment flush under new code: the blank was treated as part of the comment being written, so only the edit's own comments got one.
    -
-
  -
  -
  -
  -
  -
  - A mapping list is scanned by key: a reader hunting for what one key does runs an eye down the key column, which a verb-first entry buries mid-line.
-
- The refactor principle's trigger (a name narrower than what the code now does) decides when to rename; this rule decides what to rename to. Widening an inventory name only meets the trigger until the next change, so the trigger fires again and each rename drags its references, symlinks and history along. A role name stops the trigger from refiring, the same way the comment rule above keeps a retune from dragging a comment edit.
-
  -
  -
  -
  -
  -
  -
-
- A multi-line computation nested in a string, argument or test hides the outer line's shape: the reader has to find where it closes to see what the line does. The line-count trigger needs no judgment, so the common case can't be argued away as obvious; the opaque trigger catches one-liners that still need decoding. Clear one-line nesting is exempt because naming it adds a line and no meaning.
- Generalizes the trailing-comma rules below to any sequence, string concatenation included, where no formatter adds the terminator. The extra `""` line makes a reorder diff as a pure move.

  ```




  ```
-

  ```




  ```
- Keep a signature change line-addressable: on one line, dropping a parameter rewrites the whole `def` line, so the reviewer has to compare the old and new lines to find the one parameter that changed. The trailing comma also holds the shape in place, since formatters (ruff, black, prettier) treat it as a "magic trailing comma" and keep the list expanded instead of collapsing it back onto one line. A lone parameter (`self` on a method being the common case) stays inline: expanding it would triple the line count of every such signature, which costs more than the one rewrite that happens when a second parameter arrives. `self` counts toward the two because it takes a slot in the parameter list like any other parameter.

  ```




  ```
-

  ```




  ```
