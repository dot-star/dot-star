---
description: Move this worktree's working changes into the root checkout for live testing (sourcing dotfiles, running at the installed path); rebases the worktree onto current master if the direct apply fails. Reverse with /untry.
---

Try these changes: ferry my worktree's working-tree edits into the root checkout so I can source or run them at the installed path. Reverse with /untry when done.

If `git apply` in root fails because root has advanced and touched the same files, rebase the worktree branch onto current master (stash uncommitted edits first, pop after), regenerate the patch, and retry. Leave any rebase or stash-pop conflicts in the worktree for the user to resolve and stop; never disturb unrelated uncommitted work in root.
