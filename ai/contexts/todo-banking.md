# Todo banking

Loaded on demand: the loose-end rule in the Output section of `~/.claude/CLAUDE.md` points here before any banked todo gets written, and `remind_style_guide.sh` injects this path on every write to a `todo.md`. Section names below (Writing style) refer to that file.

**Where the entries land**, resolved in this order, first hit wins:

1. A personal record, when the todo can't sit in the repo: the repo is public, the `todo` mention doc maps it, or the user calls the todo personal. The entry goes to that repo's personal planning workspace, a `todo.md` kept in a personal repo. The mention doc (its pointer is injected on any prompt saying `todo`) maps each such repo to its workspace and names where an unmapped repo gets a new one; read it before writing.
2. A TODO section in the markdown beside the work (`todo.md`, `CLAUDE.md`, `README.md` in the directory being edited).
3. A TODO section in the repository root's markdown.
4. Neither exists: create `todo.md` at the repository root with a `# todo` heading.

Match a heading case-insensitively (`# todo`, `## TODO`, `## Todo`) and append to the end of that section, never the top; existing entries were banked first and keep their slots. Never sort the file by label: the `todo` render sorts, so reprioritizing an entry edits its label line without moving it.

**What each entry carries:** one entry per loose end, shaped like the entries already in that section (bullet marker, sentence vs. fragment), leading with an action verb per the TODO rule in Writing style. Spell out the context the chat message carried implicitly (`file_path:line_number`, what's wrong, what "it" refers to), since the reader picking this up months later has none of this session.

**Label every entry on two scales**, one label per line as the entry's last lines, so retuning one leaves the other's line untouched in the diff. `P#` is priority, when the task gets worked. `S#` is severity, how much the problem hurts while it sits there. The two are independent: a cosmetic label that takes one line to fix earns a high priority at a low severity, and a real annoyance nobody but the developer hits stays low priority. Assign both while banking, weighting priority toward effort-to-payoff (a cheap fix with a visible result ranks high even when trivial); the labels are a starting point the user corrects by hand, never a record of a decision. Rendered example:

```
- Fix the settings button needing two taps to open the modal; the first tap should open it.
  P2
  S3
```

| P | Priority: when it gets done |
|---|---|
| P0 | Drop everything |
| P1 | This week |
| P2 | Next up |
| P3 | When convenient |
| P4 | Someday |
| P5 | Only if it gets cheap |

| S | Severity: what it costs while unfixed |
|---|---|
| S0 | Shows wrong output as correct, or the thing is unusable |
| S1 | A core path is broken with no workaround |
| S2 | Broken, but a retry or a workaround gets past it |
| S3 | Degraded: friction, misreads, extra steps |
| S4 | Cosmetic |
| S5 | No defect; a feature that doesn't exist yet |

A file whose entries don't yet carry labels gets both tables added above its entries in the same edit, so a bare `P2` reads to the next person; its existing entries stay unlabeled until a backfill of their own.

**Retire a finished entry in two commits, never one:** check it off where the work lands, then delete the line later in a commit of its own. A box that goes `[ ]` to `[x]` in the same diff as the work ties the work to the task it closes. A line that vanishes in that diff reads as a dropped task, and the record of what got done goes with it.

1. `- [ ] Fix the thing` becomes `- [x] Fix the thing` in the commit that does the work.
2. The `- [x]` line gets deleted later in a prune commit that touches nothing else, often sweeping several finished entries at once.
