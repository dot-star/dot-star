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
-
  -
  -
    -
    -
-
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
