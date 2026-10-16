# Context loading

<!-- claude-mention:
    ai/contexts
    claude-mention
    claude.local
    claude_[^[:space:]]*\.md  # match CLAUDE_*.md, not a claude_* shell function
    context doc
    supplemental
-->

Loaded on demand: the Supplemental preferences section of `~/.claude/CLAUDE.md` points here before any context file gets added, moved or resized, and the `claude-mention` marker above injects this path when a prompt names the plumbing.

- Sibling `~/.claude/CLAUDE_*.md` files are auto-injected into the session context by a `SessionStart` hook, in version-sort order (`sort --version-sort`: numeric components compared as numbers, un-numbered names alphabetical after numbered). Example order: `CLAUDE_01_<name>.md`, `CLAUDE_03_<name>.md`, `CLAUDE_10_workflow.md`, `CLAUDE_testing.md`. Treat each as preferences layered on top of this file; later files override earlier ones on conflict.
  - That hook is the **always-on** channel; keep only small, every-session prefs in `~/.claude/CLAUDE_*.md`. Hook `additionalContext` is capped at 10,000 characters ([docs](https://code.claude.com/docs/en/hooks.md#size-limits)); past it the output is offloaded to a file and replaced by a ~2KB preview, silently dropping the rest, so the loader prepends a loud `⚠️` banner when the payload nears the cap. Work-specific or heavy docs go in `ai/contexts/` and ride the uncapped native-memory channel instead.
    - Give a large file its own cap by registering a second `SessionStart` entry in `settings.json` that runs the loader as `load_claude_md_supplementals.sh <name>`. The cap is per hook output, never summed, so `CLAUDE_<name>.md` then loads alone and the shared call skips it.
  - Three channels carry context, by purpose:
    - **Always-on**: `~/.claude/CLAUDE_<name>.md`, auto-loaded every session by the hook above. For small global prefs.
    - **Full doc, in-repo**: `ai/contexts/<name>.md`, pulled into one repo by a gitignored `CLAUDE.local.md` there holding `@~/.dot-star/ai/contexts/<name>.md`. Native memory import: no cap, loads only in that repo.
    - **Reference on mention**: add `<!-- claude-mention: <keyword> -->` to an `ai/contexts/` doc; the `UserPromptSubmit` companion hook then injects a one-line pointer to it (not its content) the first time a prompt mentions `<keyword>`, deduped per session.
      - List keywords one per line inside a single marker block (preferred), or comma-separated on one line; any one matches.
  - Where a new piece of context goes:

    ```
    New context to add
       │
       ▼
     Needed in EVERY session?
       ├─ yes ─► ~/.claude/CLAUDE_<name>.md          (always-on hook)
       │
       └─ no ─► tied to a specific repo?
                │
                ├─ yes ─► ai/contexts/<name>.md
                │          + <repo>/CLAUDE.local.md:  @~/.dot-star/ai/contexts/<name>.md
                │          │
                │          └─ want a nudge when mentioned from elsewhere?
                │              ├─ yes ─► add  <!-- claude-mention: <keyword> -->
                │              └─ no  ─► done (loads only in that repo)
                │
                └─ mention-only ─► ai/contexts/<name>.md + claude-mention marker
    ```
