# Commit message style

Most commits are subject-only. ~92-94% of hand-written commits across this user's repos have no body at all. When in doubt, write less. Never add `Generated with Claude Code` or `Co-Authored-By: Claude` trailers.

## Subject

- Imperative mood, capitalized first word: `Add`, `Fix`, `Use`, `Allow`, `Move`, `Remove`, `Note`, `Refine`.
- No trailing period (dead since ~2021).
- No type prefix of any kind, in any casing: not `feat:`/`fix:`/`chore:` nor `Feat:`/`Fix:`. The colon is the tell; `Fix the leak` is a valid imperative subject, `Fix: the leak` is a banned prefix. Just write the short summary.
- Aim for under ~70 chars. p95 is 67-79 across repos. Very short subjects are fine when context is obvious: `Sort`, `Use paging`, `Add alias`, `Clean up`.
- Cut the precise value, token, or mechanism the diff already carries; the subject names *what* changed, not the exact figure/character/method it changed to. ``Fix checklist tree-row indent to one U+3000 full-width space`` → ``Fix checklist tree-row indent``; ``Bump retry timeout from 5s to 30s`` → ``Bump retry timeout``. The reader opens the diff for the how-much; keep only what stays meaningful without it. This holds even when the change only adds items to a list, enum, or whitelist and cutting them seems to gut the subject: cut them anyway (``Whitelist ET and RSVP acronyms`` → ``Whitelist acronyms``), a near-empty subject is fine per the short-subject rule above, and a bare count like ``two more`` is itself a diff-carried value, so it goes too.
- Backticks around code/identifiers/paths/flags only when the literal token is the point: ``Allow `git --no-pager` log/diff/show without prompting``. Skip them otherwise.
- Name shell wrappers by what they do, not their alias. The reader may not have `s` defined, but everyone knows `git status`. Prefer ``Prefix unpushed commits in `git status` with `[dN]` diff alias`` over ``Prefix unpushed commits in `s` with `[dN]` diff alias``. If the alias name itself is the subject of the change (renaming it, defining it, removing it), include both: ``Add `[dN]` prefix to `git status` wrapper (`s`)``.
- No em dashes anywhere; use a comma, parentheses, or two clauses.
- After amending or squashing, re-read the resulting combined diff and rewrite the subject if it no longer covers what the commit now contains. Folding changes in can silently leave the old summary stale.

## Body

Default to no body. Add one only when the diff alone won't tell a future reader what they need to know. Two shapes are common; pick whichever fits.

### Shape 1: labeled evidence block

The dominant shape for `Fix` commits. A label introduces the verbatim output that motivated the change. The output is indented (4 spaces is most common, 2 also seen) so it reads as a quoted block.

Labels actually used (in rough frequency order): `Error message:`, `Error:`, `Message:`, `Warning message:`, `Error messages:`, `Fixes error:`, `Command:`, `Catch the following:`, `Before:` / `After:`.

```
Fix static type checker error

Error message:
    error: Argument of type "str | None" cannot be assigned to parameter
    "full_name_or_id" of type "int | str" in function "get_repo"
    (reportGeneralTypeIssues)
```

```
Use squash merge

Fixes error:
$ gh pr merge --auto --merge "${PR_URL}"
    GraphQL: Merge method merge commits are not allowed on this repository (enablePullRequestAutoMerge)
    Error: Process completed with exit code 1.
```

```
Fix nvm sourcing being slow

Before:
          ┌ loading zshrc
          │  ┌ nvm setup
   885 ms │  └ nvm setup
   918 ms └ loading zshrc

After:
          ┌ loading zshrc
          │  ┌ nvm setup
     8 ms │  └ nvm setup
    42 ms └ loading zshrc
```

### Shape 2: prose paragraph(s)

Plain prose explaining what the diff doesn't show. That's usually motivation (why this change), but can be mechanism when it's non-obvious. Wrap around 72 chars.

One paragraph is typical. Multi-paragraph is fine for subtle bugs.

```
Require globally unique numbering when offering choices

So replies like "2, 4, 9" map unambiguously across multi-section
prompts instead of colliding with section-local "1, 2, 3" groups.
```

```
Display bit flags in use when calling Curl::diagnose()

This change attempts to determine which underlying constants were
bitmasked together to reach the resulting value passed to curl_setopt()
using Curl::setOpt().
```

## What not to do

- No bullet lists in hand-written bodies. (Bulleted bodies appear in commits ending `(#NNN)`, but those are GitHub's squash-merge artifacts; the bullets are the constituent PR commits, not a style choice. Don't replicate them in direct commits.)
- No markdown headers (`## Summary`, `## Test plan`).
- No `Generated with Claude Code` or `Co-Authored-By: Claude` trailers.
- No em dashes.
- No trailing period in the subject.
- No type prefix in any casing (`feat:`, `Fix:`).
