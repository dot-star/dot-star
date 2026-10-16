# Worktree follow-up menu

Loaded on demand: the Output section of `~/.claude/CLAUDE.md` points here before any message that offers a worktree follow-up. Section names below (Workflow, Shell commands, the bracket-prefix list) refer to that file.

- When offering a worktree follow-up, present whichever of these bracket-prefix options apply to the moment (any subset the tree allows; 🏁 land and 🧨 close always apply, ⬆️ promote whenever there's something to move), each on its own line led by its action emoji; never bundle two actions into one option (e.g. **`[p]romote and land`**).
  - 🧨 **`[x]`** is the one designed bundle: `x` means close the session and closing a worktree session means landing it first, so the row reads land + close rather than two actions glued together.
  - 🧨🧨 **`[xx]`** is the same close without the land, per the close rows below.
  - Whenever two or more appear together, list them top-to-bottom in this fixed order: iterate → commit → fold → promote → land → close → close-as-is.
  - The slot order tracks least-to-most committal (don't-commit first, then commit-and-stay, then rewrite-and-stay, then promote, then the teardown, then the teardown plus the session's end).
  - Land is the only git action that tears the worktree down, so it's always the last git row, never floated into the middle or reordered; 🧨 **`[x]`** and 🧨🧨 **`[xx]`** are the only rows allowed beneath it.
  - Close-as-is sits under close rather than up with iterate, its committal peer, because it's `[x]`'s sub-option and reads as "the other close" only next to its parent.

  **The close rows in full**, on top of the `x` rule in Workflow, which covers the 🏁 recap offer and writing the prune mark:

  - **`[x]` lands first**, since the objective isn't complete yet, then marks and exits. The land runs exactly as 🏁 **`[L]and`** would (the commit goes through the `commit` skill on a dirty tree; `x2` picks draft 2 the way `L2` does), the 🏁 recap renders as usual, then the `/exit` nudge follows.
  - **`[xx]` is the close without the land:** mark the session for prune, then `/exit`, touching nothing in git. No commit, no promote, no teardown; the worktree and its pending change stay on disk for a later session or `wts` to pick up. The pending change is what the row protects, so it renders only on a dirty tree: once every edit is committed the branch already holds the work, and the row would offer nothing but stranding that commit in an abandoned worktree. Typed on a clean tree anyway, `xx` still does what it says; it just isn't offered there. Never make it destructive: the prune mark already discards the conversation, so after it the worktree is the only record of the work; a stale worktree costs one `rm -r` where deleted edits are gone. A discard wants its own row with a destructive verb in its name, never a close key that happens to delete. Offer it as 🧨🧨 **`[xx]`** directly beneath 🧨 **`[x]`**; the doubled letter is `[x]`'s own sub-option the way `[xN]` is, so `[x]` keeps its bare letter and `x2` still picks draft 2. It carries no subject drafts, since nothing gets committed. Its recap is ⏸️, not 🏁, since the objective isn't complete: `⏸️ Session closed, worktree left as-is`, then the checklist rows `⏸️ Worktree kept (<name>); N files uncommitted` and `🧨 Session marked for prune`.

  **Pre-send check**, run on every worktree menu:

    1. Does every row wrap its option as `**` + `` ` `` + `[x]remainder` + `` ` `` + `**`? A bare `🧹 [cl]ean` is a fail; the bold inline-code span is as mandatory here as anywhere else.
    2. Are 🏁 **`[L]and`** and 🧨 **`[x]`** both on the menu, plus ⬆️ **`[p]romote`** unless there's nothing to move? Land and close are never conditional: each commits whatever is pending first, so no tree state rules them out. Promote drops only on a clean tree with nothing ahead of the default branch (the state right after a promote), where it would fast-forward by zero commits. A menu missing a row it owes is an omission, not a narrowed menu; the other rows that drop are 💾 **`[c]ommit`**, 📦 **`[f]old`**, 🛠️ **`[i]terate`** and 🧨🧨 **`[xx]`**.
       - Does a `git status --porcelain` run this turn back the shape? Empty output is the only license for the clean-tree menu; a staged path still owes 💾 **`[c]ommit`** with its drafts and 🧨🧨 **`[xx]`**.
    3. Is 🛠️ **`[i]terate`** the top row? Only ⚡ **`[n]ow`** and 📋 **`[a]dd`** may sit above it, in that order.
    4. Does 🧨🧨 **`[xx]`** render only over a dirty tree, and on a dirty tree is it the bottom row, with 🧨 **`[x]`** directly above it and 🏁 **`[L]and`** above that? A clean tree ends on 🧨 **`[x]`** instead. If any other option (even a lone keep/iterate slot) renders beneath 🏁 **`[L]and`**, reorder before sending.
    5. Is there exactly one space between each emoji and its bracket span? The column padding goes after the closing `**`, before the `(`, never between the emoji and the bracket.
       - Does that padding put every `(` in one column, ⚡ and 📋 rows included? Pad per the alignment rule in the bracket-prefix list.
    6. Does every decision the message body left open have a row here? Re-read the prose above for nits, 💅 polish notes, 🔄 heads-ups, and 🔴 blockers; each one the user could accept needs its own row under the same letter and emoji, per the bracket-prefix checklist. A menu that omits one sends the reader back to typing a sentence.
    7. Does the 💾 commit row carry the subject drafts beneath it, does the 📦 fold row carry its own `[fN]` drafts against the combined diff, and do the ⬆️ promote, 🏁 land and 🧨 close rows each carry their `[pN] ...` stand-in? A committing row with none costs the user a round trip through the skill's pick step.
    8. Is the change the drafts describe staged? Every `[cN]` tree needs its paths in the index before the menu renders, per the staging rule below; a menu with drafts over an unstaged change sends the user back to asking for the staging before they can judge the subjects.
    9. Would a behavior-preserving restructure of a touched line shrink this diff? Read the staged diff's deleted lines: a long paragraph replaced by a copy of itself with one clause changed is the tell, since the reviewer sees a rewrite where the intent is one sentence.
       - **Split first, unasked:** catch it before editing when the plan already shows one clause changing inside a dense paragraph. Caught only at the menu, set the change aside, restore the file, apply just the restructure (bullets, or an extracted helper) and stage it. The commit row's drafts then describe the refactor and its parenthetical says the change reapplies on top after it.
       - **Lead the note with 🪚, never 💅:** the principle requires the split, so it isn't optional polish.
       - The refactor principle in `CLAUDE.md`'s Principles already asks for the split; this item is the one that fires, since only the list gets run against the menu in hand.

  **Subject drafts ride under every row that commits.** Whenever the tree is dirty, draft subjects the way the `commit` skill does (over-generate, score, rank) and render the top three beneath each of 💾 **`[c]ommit`**, 📦 **`[f]old`**, ⬆️ **`[p]romote`**, 🏁 **`[L]and`** and 🧨 **`[x]`** as a tree sub-list, the same shape as the 🏁 checklist's commit list:

  - **Row shape:** each row indented with 2 ideographic full-width spaces (U+3000) + 1 regular space so the glyph lands under the `[` of the parent row, a `├─` on each row and `└─` on the last, then the bracket token `**` + `` ` `` + `[cN]` + `` ` `` + `**` (or `[fN]`, `[pN]`, `[LN]`, `[xN]`, the parent's letter plus the draft number), a space, and the subject in plain text. The subject stays plain because it's text to compare, not an option name.
  - **Spelled out once:** the subjects sit under the commit row; the promote, land and close rows each carry a single stand-in row instead of a tree, `[pN] ...`, `[LN] ...`, `[xN] ...` with a literal `N`, so the accept-token shape is on screen without three rows of `...` repeating three times. The stand-in takes a `└─`, since it's the last row under its parent, the same way `└─` closes the commit row's list.
  - **One tree per staged commit:**
    - A menu covering commits in two or more repos renders a draft tree under each repo's staged commit.
    - Number the drafts globally unique across the message (`[c1]`-`[c3]` for the first commit, `[c4]`-`[c6]` for the second), so a single `c<N>` names one draft of one commit.
    - Never float a commit's subject in prose beside another commit's tree; a subject with no token can't be picked, so it reads as decided when it isn't.
  - **Fold unstales the subject it amends**, so its row carries a tree too: draft it against the combined diff (HEAD's change plus the pending one), which is what the amended commit will hold, and number it after the commit row's drafts, `[f4]`-`[f6]` under a `[c1]`-`[c3]` commit row, so one number names one draft. A bare `f` keeps HEAD's subject, the right pick whenever that subject already covers the combined diff; `f<N>` amends with draft N instead. The tree renders on every fold, since whether the old subject still covers the folded-in change is the question the drafts answer, so leaving them off when it looks fine is the guess they replace.
  - **Bare `c` still runs the skill** and shows the full list of five.

  **Stage the change before rendering its drafts.** A subject is judged against the diff it describes, so the diff has to be one command away while the drafts are on screen: once the paths are in the index, a bare `d` in another terminal shows `git diff --cached` (`rc_diff` prefers the staged diff when one exists) and `s` lists the staged files, which is exactly what the picked draft would commit. Whenever a menu carries a `[cN]` tree, run `git add -- <path> [<path> ...]` over the paths this session edited first, under the same explicit-path and `git status --porcelain` checks the staging rule in Shell commands sets, and say so in a line above the menu (`🟢 Staged 2 files`) so the user knows `d` is live. Re-run it on every menu, since edits made after an earlier staging land unstaged.

  - **Draft only what's staged:** the index holds one commit, so a repo with several pending commits stages only the first one's paths and renders only that commit's tree.
    - Name that commit above the menu (`🟢 Staged 1 file for commit 1 of 4`).
    - Name it again in every row whose parenthetical opens with `commit` (`💾 [c]ommit (commit 1 of 4)`), so the row picked says which commit it banks.
    - Give each later commit its tree on the menu after the one before it lands; a tree over unstaged paths asks the user to judge subjects they can't `d`.
  - **Fold gets the same staging**, since `git commit --amend --no-edit` commits the index too.

  **Applicability is a fact about the tree, not a guess.** Before sending, run `git status --porcelain` and branch on the result:

  - **Non-empty** (something is actually uncommitted): offer `[c]ommit`, plus `[f]old` when both of these hold:

    - **HEAD isn't on the remote default branch.**
      - Run the check, don't assume: `git merge-base --is-ancestor HEAD <remote>/<default>` exits nonzero, taking `<remote>` from `git remote` rather than assuming `origin`.
      - Published history means the remote default branch's, so an unpushed commit on local `<default>` (main-checkout work) still folds; a HEAD already there gets no fold slot, since amending it rewrites commits everyone else builds on.
      - A pushed PR branch is fair game: keep the fold row and name the cost in its parenthetical (`amend into HEAD + force-with-lease push`, plus any stacked PR that then needs a rebase).
    - **The pending change belongs to HEAD's commit**, finishing or fixing that one intent rather than standing on its own (atomic commits). A change that deserves its own subject gets `[c]ommit`, not `[f]old`.

  - **Empty** (clean tree): drop `[c]ommit`, `[f]old` and `[xx]`, reframe `[i]terate` from "defer the commit" to "keep tuning", and narrow the menu to `[i]terate`/`[p]romote`/`[L]and`/`[x]` (they act on the already-committed work, or leave it where it is). `[xx]` goes because the work it guards is already in a commit, per the close rows above.

    - **Nothing ahead of the default branch** (`git rev-list --count master..HEAD` prints `0`): drop `[p]romote` too, since it would fast-forward by zero commits, and cut `✅ promote to master` from the `[L]and` and `[x]` parentheticals, leaving the teardown they still do.

  Pick the menu shape from a `git status --porcelain` run in the same turn, never from a mental model of the tree. The model goes stale both ways:
  - **Offering a commit on a clean tree:** edits that net back to the committed value leave nothing to commit.
  - **Dropping the commit on a dirty tree:** a staged file (`M ` in the first column) is still uncommitted, so "staged it" never means "committed it". Staging is the step before every `[cN]` tree, so a turn that just staged owes the dirty-tree menu.

  The common options:
  - 🛠️ **`[i]terate`**: no commit yet, keep iterating in the worktree (the do-nothing default, named for the action rather than a passive "keep").
  - 💾 **`[c]ommit`**: commit, keep iterating in the worktree (commits what's there; `[i]terate` defers the commit). Carries its three `[cN]` subject drafts beneath it.
  - 📦 **`[f]old`**: amend the pending change into HEAD with `git commit --amend --no-edit`, keep iterating in the worktree. Carries its three `[fN]` subject drafts beneath it, scored against the combined diff; picking one swaps the `--no-edit` for `--message "<subject>"`, so the amended commit carries the new subject.
  - ⬆️ **`[p]romote`**: commit + fast-forward the default branch to here, keep the worktree (via `worktree-promote`). Carries a single `[pN] ...` stand-in for the commit row's numbering when the tree is dirty.
  - 🏁 **`[L]and`**: commit + promote + tear down the worktree (via `worktree-done`). Carries a single `[LN] ...` stand-in for the commit row's numbering when the tree is dirty.
  - 🧨 **`[x]`**: commit + promote + tear down the worktree + mark the session for prune + `/exit`, per the close rows above. The parenthetical spells out the land row's steps rather than saying `land +`, since every option is self-contained. Carries a single `[xN] ...` stand-in for the commit row's numbering when the tree is dirty.
  - 🧨🧨 **`[xx]`**: mark the session for prune + `/exit`, touching nothing in git (no commit, no promote, no teardown), per the close rows above. The worktree and its pending change stay on disk for a later session. Renders only on a dirty tree, since that pending change is what the row is for. Carries no drafts, since nothing gets committed.

  **A one-off option outside the standard rows** (e.g. 🧹 **`[cl]ean`** to delete dead code before committing) slots by how committal it is, next to the standard row it most resembles: edit-and-defer sits with 🛠️ **`[i]terate`**, edit-then-commit sits with the 💾 commit row. It never takes the top row from 🛠️ **`[i]terate`** or the bottom rows from 🏁 **`[L]and`**, 🧨 **`[x]`** and 🧨🧨 **`[xx]`**. It may fold its own commit in (as promote and land do), but never a second menu action's git state change. When its natural letter collides with a standard row's, both sides extend: a clean row turns the commit row into 💾 **`[co]mmit`**, so the menu reads 🧹 **`[cl]ean`** vs 💾 **`[co]mmit`**.

  Rendered examples (show only the options that apply, always in this order; pad the bracket-name column with trailing spaces so the open-parens line up). On a dirty tree the commit, fold, promote and land rows each carry the subject drafts; the later examples leave them out to keep the shapes short:

  Full set:

  > 👉 How do you want to proceed?
  >   🛠️ **`[i]terate`** (no commit + keep iterating)
  >   💾 **`[c]ommit`**  (commit + keep iterating)
  > 　　 ├─ **`[c1]`** Keep search input usable under long title
  > 　　 ├─ **`[c2]`** Give open search box room when title is long
  > 　　 └─ **`[c3]`** Stop long title squeezing search input to nothing
  >   📦 **`[f]old`**    (amend into HEAD + keep iterating)
  > 　　 ├─ **`[f4]`** Add search box that stays usable under long title
  > 　　 ├─ **`[f5]`** Add search box to toolbar
  > 　　 └─ **`[f6]`** Add search box that yields to title
  >   ⬆️ **`[p]romote`** (commit + ✅ promote to master)
  > 　　 └─ **`[pN]`** ...
  >   🏁 **`[L]and`**    (commit + ✅ promote to master + 🪓 tear down worktree)
  > 　　 └─ **`[LN]`** ...
  >   🧨 **`[x]`**       (commit + ✅ promote to master + 🪓 tear down worktree + 🧨 close session)
  > 　　 └─ **`[xN]`** ...
  >   🧨🧨 **`[xx]`**    (no commit + worktree left as-is + 🧨🧨 close session)

  Subset (e.g. nothing worth keeping uncommitted, so no iterate slot):

  > 👉 How do you want to proceed?
  >   ⬆️ **`[p]romote`** (commit + ✅ promote to master)
  >   🏁 **`[L]and`**    (commit + ✅ promote to master + 🪓 tear down worktree)
  >   🧨 **`[x]`**       (commit + ✅ promote to master + 🪓 tear down worktree + 🧨 close session)
  >   🧨🧨 **`[xx]`**    (no commit + worktree left as-is + 🧨🧨 close session)

  Subset (clean tree, so no commit, fold or close-as-is slot; iterate reframed to keep tuning):

  > 👉 How do you want to wrap up?
  >   🛠️ **`[i]terate`** (keep tuning in the worktree)
  >   ⬆️ **`[p]romote`** (✅ promote to master)
  >   🏁 **`[L]and`**    (✅ promote to master + 🪓 tear down worktree)
  >   🧨 **`[x]`**       (✅ promote to master + 🪓 tear down worktree + 🧨 close session)

  Subset (clean tree just promoted, so nothing ahead of master and no promote slot):

  > 👉 How do you want to wrap up?
  >   🛠️ **`[i]terate`** (keep tuning in the worktree)
  >   🏁 **`[L]and`**    (🪓 tear down worktree)
  >   🧨 **`[x]`**       (🪓 tear down worktree + 🧨 close session)

  Subset (a follow-up edit that finishes the HEAD commit, not yet on master, so fold joins commit):

  > 👉 How do you want to proceed?
  >   🛠️ **`[i]terate`** (no commit + keep iterating)
  >   💾 **`[c]ommit`**  (commit + keep iterating)
  >   📦 **`[f]old`**    (amend into HEAD + keep iterating)
  >   ⬆️ **`[p]romote`** (commit + ✅ promote to master)
  >   🏁 **`[L]and`**    (commit + ✅ promote to master + 🪓 tear down worktree)
  >   🧨 **`[x]`**       (commit + ✅ promote to master + 🪓 tear down worktree + 🧨 close session)
  >   🧨🧨 **`[xx]`**    (no commit + worktree left as-is + 🧨🧨 close session)

  The doubled emoji pushes the 🧨🧨 row's open-paren two cells right of the column; leave it, since widening every other row's padding costs more than the offset, which also marks the row as the odd one out.

  Why the rows sit where they do:
  - Bundling forces actions when the user often wants just to keep iterating.
  - Commit and fold are the two ways to bank the same pending change, so they sit adjacent.
  - Promote and land share the fast-forward but only land removes the worktree.
  - Close is a land plus the session's end, the one step more committal than a land, so it sits beneath it.
  - Close-as-is is the close with the land taken out, so it sits beneath close as its variant.
  - **`[L]and`** leads with 🏁 (not the 🛬 land marker) to flag that picking Land completes the objective; the 🏁 goes at the front of the Land line, not trailing after the `?`.

  **The 🏁 recap after a land, promote or close** follows the 🏁 checklist convention in Output, listing these steps in lifecycle order:

    - ✅ Committed N commits, then list each subject beneath as a tree sub-list (newest-first); a lone commit is a single `└─`. Wrap each subject in inline-code backticks so it renders in the inline-code accent and indent each glyph with 2 ideographic full-width spaces (U+3000) + 1 regular space, landing the `├`/`└` under the first letter of the step text (the `C` of `Committed`), not under the `✅` (plain leading spaces collapse in rendered markdown, so the wide U+3000s hold the indent):
　　 ├─ `<newer commit subject>`
　　 └─ `<older commit subject>`
    - ✅ Promoted to master (on land too: a land is a promote plus a teardown, and the row matches the ⬆️ menu wording rather than naming the fast-forward underneath)
    - ✅ Pushed to `<remote>` (only when the user asked for the push in words; land and promote are local, so this line is absent by default and is never a step to run, and a configured upstream doesn't earn it or a ⏸️)
    - 🪓 Worktree removed (land) or `⏸️ Worktree kept (<name>); promote keeps it, land tears it down` (promote). The kept line always names why it survived, since a bare "kept" reads as an oversight and prompts a "why not tear down?" round trip.
    - 🧨 Session marked for prune (close only)

    Fired means over the whole objective, not the latest turn: a land after a promote renders the promote's rows again (the `✅ Committed` tree, then `✅ Promoted to master`) ahead of the 🪓, so the recap reads the same whether the promote happened a turn earlier or never. A free-form `master already carried N commits` row hides the subjects and invites a hash.

    Order the rows by clock, except 🪓, which stays the last git row however things unfolded: a commit that lands after the teardown (a follow-up in another repo) still slots above it as its own `✅ Committed N commits (<repo>)` row. A 🪓 above a commit list reads as torn down before the work was banked. 🧨 is the one row allowed beneath it, mirroring the menu, where the close rows are the only ones beneath 🏁 **`[L]and`**.
