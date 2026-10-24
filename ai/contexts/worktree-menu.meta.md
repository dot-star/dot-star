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
       -
       -



  -
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
    -
      -
      -
      -
      -

      ```




      ```
    - The parenthetical has to say the row can bank more than the staged commit, or `c1 c4` looks like it does more than the row promised.
    - Replaces the old reason for withholding later trees (subjects you can't `d`): `dw` shows the unstaged diff, so the later commit's subjects can be judged in place.
    - Land and close came back mid-series once every commit has a subject on screen. A pick that names only some commits would still strand the rest in a worktree about to be deleted, so the refusal keeps that failure impossible rather than merely unlikely.
    - The one case the old mid-series drop still covers: a change set aside behind a refactor-first split isn't on disk, so `dw` can't show it and a land can't commit it.
  -



  -

    -
      -
    -
      -
      -
      -

  -

    -


  -
  -


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

   Shows the series shape end to end: the progress block, both labeled trees with their view commands and the stand-ins carrying one `N` per commit.

  ```


  ```

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




