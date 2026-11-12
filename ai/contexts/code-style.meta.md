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
  -
    -
    -
-
-
-
  -
  -
  -
  -
  -
  -
-
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
