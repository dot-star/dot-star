# File naming

When creating a file, the name should be both **hierarchical** (shared prefix so related files cluster together in a directory listing) and **semantic** (the remainder hints at what the file does, supplements, or contains). Together they turn `ls` into a table of contents: related files cluster without needing a subdirectory, and a reader needn't open a file to know what it does.

## Shapes by extension

- `.sh`: name says what running it accomplishes (verb/outcome, not category). E.g. `install.sh`, `post_install.sh`, `update.sh`, `safer_rm_test.sh`.
- `.txt`: name says the topic of the notes inside.
- `CLAUDE_<slug>.md`: slug says what aspect of `CLAUDE.md` it supplements. E.g. `CLAUDE_slack-style.md`.
- Style files: `styles/<topic>-style.md` for on-demand style guides. E.g. `commit-message-style.md`, `shell-style.md`, `file-naming-style.md` (this file).
- Memory files: `<type>_<topic>.md` (e.g. `feedback_pipe_newlines.md`); the type prefix groups by kind, the topic suffix names the rule.
- Top-level project docs: `<TOPIC>.md` uppercase (`README.md`, `CHANGELOG.md`, `SECURITY.md`, `TESTING.md`, `TROUBLESHOOTING.md`).
- Tool directories: name the tool (`bash/`, `brew/`, `docker/`, `node/`, `python/`, `vim/`, `zsh/`); when several tools share a category, name the category instead (`version_control/` for git/hg).

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

More patterns from `php-curl-class/examples/` and `tests/`:

- **Sibling prefixes mirror parent families.** When a parallel set of functionality exists, the new family's filenames mirror the first's vocabulary token-for-token: `curl_after_send.php` ↔ `multi_curl_after_send.php`, `curl_before_send_retry.php` ↔ `multi_curl_before_send_retry.php`. Pick the matching suffix instead of inventing a new one.
- **Auxiliary files distinguished by an infix or hyphenated suffix.** `*.inc.sh` marks include-only shell (`display_errors.inc.sh`, `set_vars.inc.sh`). `*-baseline.<ext>` marks a tool baseline next to its config (`phpstan.neon` + `phpstan-baseline.neon`, `psalm.xml` + `psalm-baseline.xml`).
- **Same task, multiple implementations: share the base, vary the extension.** `generate_urls.py` + `generate_urls.sh`.
- **Casing encodes file role.** PascalCase for class files (`Helper.php`, `RangeHeader.php`, `User.php`), snake_case for scripts (`run_phpunit.sh`, `generate_urls.py`), uppercase for top-level project docs (`README.md`, `TESTING.md`).
- **Verb-first for executable scripts.** `run_*.sh`, `bump_*.php`, `download_*.php`, `update_*.sh`, `display_*.inc.sh`. The first token is the action; reading the name out loud describes what running it does.

## When creating any new file

1. Is there an existing group it belongs in? If yes, match the prefix.
2. Does the remainder of the name tell a reader what the file does/contains/supplements? If no, rename until it does.
3. Avoid generic names like `utils.sh`, `notes.txt`, `helper.md`, `misc.md`.
