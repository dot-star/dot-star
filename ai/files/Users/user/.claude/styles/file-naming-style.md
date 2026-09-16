# File naming

When creating a file, the name should be both **hierarchical** (shared prefix so related files cluster together in a directory listing) and **semantic** (the remainder hints at what the file does, supplements, or contains). Together they turn `ls` into a table of contents: related files cluster without needing a subdirectory and a reader needn't open a file to know what it does.

## Shapes by extension

- Executable scripts (`.sh`, `.py`, anything run rather than sourced): name says what running it accomplishes, verb-first. E.g. `install.sh`, `post_install.sh`, `update.sh`, `safer_rm_test.sh`. Read the first token alone: if it can open a noun phrase (`session_color`, `statusline`, `worktree_marker`), it names a thing, not an action; rename until it reads as an instruction (`color_tab_per_session`, `render_statusline`, `record_worktree_for_statusline`).
- Hook scripts (anything fired by an event, not invoked by hand): name the trigger and the outcome, not just the verb, since the reader has to work out when it fires and what it wants from them. E.g. `chime_when_reply_ready_to_review.sh`, `chime_when_waiting_on_user_to_answer.sh`. Shape: `<verb>_when_<trigger>_to_<outcome>`, with `when_` and `to_` dropped only when the verb's object already carries them (`enforce_executable_bit.sh`, `block_hidden_characters.py`).
- `.txt`: name says the topic of the notes inside.
- `CLAUDE_<slug>.md`: slug says what aspect of `CLAUDE.md` it supplements. E.g. `CLAUDE_slack-style.md`.
- Style files: `styles/<topic>-style.md` for on-demand style guides. E.g. `commit-message-style.md`, `shell-style.md`, `file-naming-style.md` (this file).
- Memory files: `<type>_<topic>.md` (e.g. `feedback_pipe_newlines.md`); the type prefix groups by kind, the topic suffix names the rule.
- Top-level project docs: `<TOPIC>.md` uppercase (`README.md`, `CHANGELOG.md`, `SECURITY.md`, `TESTING.md`, `TROUBLESHOOTING.md`).
- Tool directories: live under `tools/`, named for the tool (`tools/bash/`, `tools/brew/`, `tools/docker/`, `tools/node/`, `tools/python/`, `tools/vim/`, `tools/zsh/`); when several tools share a category, name the category instead (`tools/version_control/` for git/hg).

## Grouping rule

When several files are related, give them a shared prefix so they sort together in `ls`. Don't scatter related files under unrelated names.

When the files vary along one axis (level, stage, format), keep that axis in a **consistent position** so the family reads as a template. Example from `php-curl-class/scripts/`:

```
bump_major_version.php
bump_minor_version.php
bump_patch_version.php
make_release.py
make_release_recreate.sh
make_release_requirements.in
make_release_requirements.json
make_release_requirements.txt
make_release_update_requirements.sh
pre-commit.sh
pre_commit_stable.py
update_readme_methods.sh
```

- `bump_<level>_version.php`: variable axis (major/minor/patch) in the middle position, constants on either side.
- `make_release*`: shared prefix gathers the release-tooling family; `make_release_requirements.<ext>` nests a sub-family where the axis is the extension.
- `update_readme_methods.sh`: verb-first reads as an action.

The position is only visible once a second file exists. `private-todo.md` reads fine alone, but a second repo's list can only be `private-todo-<repo>.md`, burying the axis at the end. Naming it `private-dot-star-todo.md` up front leaves `private-<repo>-todo.md` free and keeps the kind as the trailing token.

**A bare name means the same thing in every family.** The unsuffixed file holds the behavior; each suffixed sibling holds a supporting piece (`_models` for the shapes the behavior works on, `_table` for the data it reads, `_test` for its tests). A family that hands the bare name to its shapes instead teaches a convention the next family breaks, so a reader who learns one family guesses wrong on the other. Example:

```
billing.py          behavior
billing_models.py   shapes
pricing.py          behavior
pricing_models.py   shapes
pricing_table.py    data
```

`pricing_models.py` reads no better than `pricing.py` would in isolation. It earns the suffix by keeping `billing.py`'s promise that a bare name is where the work happens, which is what lets a reader open the right file without listing the directory first.

More patterns from `php-curl-class/examples/` and `tests/`:

- **Sibling prefixes mirror parent families.** When a parallel set of functionality exists, the new family's filenames mirror the first's vocabulary token-for-token: `curl_after_send.php` ↔ `multi_curl_after_send.php`, `curl_before_send_retry.php` ↔ `multi_curl_before_send_retry.php`. Pick the matching suffix instead of inventing a new one.
- **Auxiliary files distinguished by an infix or hyphenated suffix.** `*.inc.sh` marks include-only shell (`display_errors.inc.sh`, `set_vars.inc.sh`). `*-baseline.<ext>` marks a tool baseline next to its config (`phpstan.neon` + `phpstan-baseline.neon`, `psalm.xml` + `psalm-baseline.xml`).
- **Same task, multiple implementations: share the base, vary the extension.** `generate_urls.py` + `generate_urls.sh`.
- **Casing encodes file role.** PascalCase for class files (`Helper.php`, `RangeHeader.php`, `User.php`), snake_case for scripts (`run_phpunit.sh`, `generate_urls.py`), uppercase for top-level project docs (`README.md`, `TESTING.md`).
- **Verb-first for executable scripts.** `run_*.sh`, `bump_*.php`, `download_*.php`, `update_*.sh`, `display_*.inc.sh`. The first token is the action; reading the name out loud describes what running it does.

## When creating any new file

1. Is there an existing group it belongs in? If yes, match the prefix.
2. Name the second file before settling on the first. If the next sibling can't slot in without renaming this one, the variable part sits in the wrong position: `private-todo.md` forces a second repo's list to become `private-todo-<repo>.md`, while `private-dot-star-todo.md` leaves `private-<repo>-todo.md` free.
3. Does the remainder of the name tell a reader what the file does/contains/supplements? If no, rename until it does.
4. Does it hold shapes, data, or tests rather than behavior? Then it carries the matching suffix (`_models`, `_table`, `_test`); the bare name is reserved for the behavior.
5. Avoid generic names like `utils.sh`, `notes.txt`, `helper.md`, `misc.md`.
