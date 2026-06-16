---
name: rename-session
description: Compose a short, descriptive session title for the `/rename` built-in and copy a ready-to-paste `/rename <title>` to the clipboard with `pbcopy`. The title is a brief plain-language description (not a slug), and a relevant PR is appended when one exists. TRIGGER when the user's whole message is exactly `ren`, when they invoke `/rename-session`, ask for a "name"/"title" for the session, ask to "name the session", or want a `/rename` line drafted for the current work. SKIP when the user wants to rename to a fixed prune marker like `del` (that is the literal `/rename del`, no drafting needed), or is asking about the `/rename` built-in itself rather than a name for this session.
---

# Rename session

The `/rename` built-in sets the session's displayed title (the statusline objective). This skill drafts that title from what the session actually did and hands back a ready-to-paste `/rename <title>` on the clipboard, so naming a session is one invocation instead of hand-composing the line each time.

The skill cannot run `/rename` itself (a built-in slash command, not a tool); it produces the line and copies it, the user pastes it.

## Derive the title

1. Read the session's objective from the conversation: what the work accomplished or is about, not the literal first message. Prefer the concrete deliverable (e.g. "Colorize git stderr warnings") over a vague restatement of the ask.
2. Write a short, descriptive title:
   - A brief plain-language description, **not a slug**: real words and spaces (`Colorize git stderr warnings`), never kebab-case (`colorize-git-stderr`).
   - Lead with intent and name the concrete thing, same rubric as a commit subject.
   - Keep it short, roughly 3 to 8 words. No leading `/rename`, no trailing period.

## Attach a relevant PR

Check for a PR tied to this work; append it only when one genuinely exists.

```
git rev-parse --is-inside-work-tree   # bail quietly if not a git repo
gh pr list --head "$(git branch --show-current)" --json number,url
```

- One match: append `#<number>` to the title (e.g. `Colorize git stderr warnings #123`).
- A PR was discussed in the session but isn't the current branch's head PR: use that one instead.
- No PR, not a git repo, or on the default branch with nothing open: skip silently, no placeholder.

## Compose and copy

1. Build the line: `/rename <title>` (with `#<number>` appended when a PR was found).
2. Copy it with `pbcopy` **only**. Never run `pbpaste`.

   ```
   printf '%s' '/rename <title>' | pbcopy
   ```

3. Show the user the composed `/rename ...` line and note whether a PR was attached. They paste it to apply.
