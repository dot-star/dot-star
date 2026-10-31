#



-
  - Land and close used to vanish for the whole series; now that every commit in a series gets a draft tree, they can bank it all, so the only state that still rules them out is a change held off disk where no tree can describe it.
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
       - Narrowed from every mid-series menu to the set-aside case: a later commit sitting unstaged on disk now has drafts, so a land can name its subject too and nothing gets stranded.
       -
       -
       -
    3.
    4.
       -
       - Follows line 23: the menu without land and close now only happens behind a set-aside change, so the bottom-row rule names that case.
       -
    5.
       -
    6.
    7.
       -
       -
       -
       - A lone `N` under promote, land or close read as a single pick even when the commit row above offered two trees; the repeated `N` makes the shape match what the reply has to carry.
    8.
    9.
       -
       - The deleted-lines tell only catches a restructure that shrinks the diff; an outgrown name leaves no trace, since the feature's diff never touches the name's own line. Reading the names the new case flows through is the only check that catches it before the rename slips behind the feature as polish.
       -
       -



  -
    - Draft numbers run across the whole menu, so a fold tree often holds two-digit tokens; a fixed pad only fits one width, so derive it from the tokens beside it.
  -
    - The stand-in is the only place promote, land and close show their reply shape, so it has to show one number per tree or it understates the pick.
  - Dropped `staged` because a series' later commits are unstaged yet still get trees.
    - A series in one worktree is the same problem as commits spread over several: more than one commit is on the table, so each needs its own subjects. Showing only the staged one hid that a second commit was coming and left no way to name it in the same reply.
    - The label has to say how to see each commit's diff, since only the first one is in the index: `d` shows the staged diff, `dw` the unstaged one the later commit will hold.
      -
    -
    -
    - Lets one reply bank part or all of the menu. A series has to go in order because each commit builds on the one before, so a pick that skips the first would commit the later change on a tree that still holds the earlier one unstaged.
  -
    -
    -
    -
    -
    -
    -
    -
  -



  -
  -
  -
  -
  - The index still holds only one commit, so staging stays limited to the first; what changed is that the later commits get drafted anyway instead of waiting for their own menu.
    - Folding the progress into the commit tree puts each pending commit's position beside the subjects that would bank it, so the reader never matches rows across two lists.
      - Listing what landed under the question keeps the whole series inside the menu the reader already scans.
      - The rail ties the landed commits to the pending ones so the series reads as one tree; drawn from the first menu, it keeps one shape across the series and gives every plain-space row a first character the renderer can't strip.
      - The marker emoji color-code each commit's state so the column scans at a glance; the files drop to their own line so the label stays short enough to scan.
      - Replaces the old reason for withholding later trees (subjects you can't `d`): `dw` shows the unstaged diff, so the later commit's subjects can be judged in place. A bare `dw` shows every unstaged commit at once, so two later trees would carry the same hint for different diffs; the paths narrow it to one, since `rc_diff_unstaged` passes them through to `git diff`. A file split by hunk between two commits can't be narrowed by path, so the label says so rather than implying an isolated view.
      - Wide spaces mixed with plain ones throw the columns off, so one kind of space keeps every glyph where the rule puts it.
      - A title over position-labeled rows repeats the position each row already states.

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
      >
      >
      >
      >
    - The parenthetical has to say the row can bank more than the staged commit, or `c1 c4` looks like it does more than the row promised.
    - Land and close came back mid-series once every commit has a subject on screen. A pick that names only some commits would still strand the rest in a worktree about to be deleted, so the refusal keeps that failure impossible rather than merely unlikely.
    - The one case the old mid-series drop still covers: a change set aside behind a refactor-first split isn't on disk, so `dw` can't show it and a land can't commit it.
  -



  -

    -
      -
      - Mirrors the cross-repo exception to the refactor-first split in CLAUDE.md's Principles, so a split made at planning still gets caught at the menu.
    -
      -
      -
      -

  -

    -


  -
  -


  -
  -
  -
    -
    -
  -
  -
  -
  -







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
  >
  >
  >
  >
  >
  >
  >

   Shows the series shape end to end: the rail drawn before anything lands, both position-labeled trees with their view commands and the stand-ins carrying one `N` per commit.

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




