# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude Code config lives in the user-global slot only

There are two `CLAUDE.md` files in this repo with different scopes:

- `./CLAUDE.md` (this file) is the project guide for working *on* dot-star itself.
- `ai/files/Users/user/.claude/CLAUDE.md` is the user-global memory that ships with this repo and applies when *using* dot-star (and anywhere else Claude runs on this machine).

There is no project-scoped `.claude/settings.json` here on purpose (`.claude/` is gitignored). The user's global config at `~/.claude/settings.json` is itself a symlink into this repo at `ai/files/Users/user/.claude/settings.json` (set up by `script/install.sh`), so editing that file is how you change Claude Code behavior, both inside this checkout and everywhere else on the machine.

`script/install.sh` also symlinks the parent dirs `ai/files/Users/user/.claude/skills`, `commands`, and `hooks` into `~/.claude/`, so new files under any of them are picked up automatically after install. To alias a slash command, symlink the new name to the existing one (e.g. `cm.md -> commit.md`); the same trick works for skills and hooks.

## Objective

Make everyday CLI work faster and safer. Aliases collapse common git operations (`cm`, `add`, `co`, `push`, `s` = `git status`, `d` = `git diff`) and wrap dangerous defaults like `rm *`. Many are context-sensitive: `s` and `d` dispatch on argument count and whether the cwd is a git repo (see `tools/bash/.aliases.sh` `conditional_s` / `conditional_d`).

## What this repo is

`dot-star` is a dotfiles / shell-environment project. It installs itself by symlinking the working tree to `~/.dot-star` and wiring `~/.bashrc` (and the zsh equivalent) to source a single bootstrap, which in turn sources every `tools/*/.aliases.sh` (and a few other named scripts) from this repo.

Compatibility targets: macOS and Ubuntu (`script/post_install.sh` branches on `$OSTYPE`).

## Commands

- Install / update: `./install.sh`. `./update.sh` is a symlink to the same script and detects the invocation name to decide whether to also `git pull` and `brew upgrade` (see `script/update.sh`). Inside an installed shell, the alias `dotstar` runs the update.
- Lint (matches CI in `.github/workflows/lint.yml`): `pre-commit run --all-files`. The only configured hook is `shfmt --indent=4 --diff --write` over shell files (see `.pre-commit-config.yaml`).
- Run the safer-rm test suite: `bash tools/bash/.safer_rm_test.sh` (the only self-contained automated test in the repo).
- Reload the shell environment after editing without re-installing: `source ~/.dot-star/bootstrap/.bash_profile`.

## Architecture

### Single bootstrap, fan-out to per-tool dirs

`bootstrap/.bash_profile` is the spine. It `cd`s to the repo root and explicitly `source`s a curated list of files, in order. The pattern is one directory per tool under `tools/` (`tools/brew/`, `tools/django/`, `tools/docker/`, `git`-via-`tools/version_control/`, `tools/node/`, `tools/php/`, `tools/python/`, `tools/vim/`, `tools/zsh/`, etc.), each containing an `.aliases.sh` that defines functions and aliases for that tool. Cross-cutting bash files live under `tools/bash/`.

Consequences for changes:

- Adding a new tool directory does nothing until you also add a `source "tools/newtool/.aliases.sh"` line to `bootstrap/.bash_profile`. The bootstrap does not glob.
- Some files are bash-only and are guarded with `if [[ -n "${BASH_VERSION}" ]]`; zsh users get a smaller set (notably `tools/bash/.behavior.sh` and `tools/bash/.prompt.sh` are skipped). Mirror that guarding when adding shell-specific features.
- Aliases and functions are intentionally short and overlap by design (e.g. `cmc`/`cgc`/`clc`/`clcm`/`cma`/`aic` all alias `claude_git_commit` in `ai/.aliases.sh`). Don't "deduplicate" these without asking; the redundancy is the point.
- `tools/bash/extra.sh` is gitignored and may be a symlink into another repo; treat it as user-local override territory and don't commit content there.

### Install-time side effects live in `script/post_install.sh`

`script/install.sh` only handles symlinks and bootstrap markers; the heavyweight machine setup (brew formulae/casks, `apt-get` packages, global git config, vim color/swap dirs, fzf, ipython profile, macOS `defaults write` tweaks, etc.) is in `script/post_install.sh`. When adding a new dependency, decide whether it belongs as a symlink in `install.sh` or a package install in `post_install.sh`.

`tools/bash/.install_check.sh` nags at shell startup when one of those two files has changed since the last `./install.sh` run, comparing the commit stamp at `~/.dot-star-installed-commit` against `git -C ~/.dot-star rev-parse HEAD`. Edits elsewhere take effect on re-source and don't trigger the nag, so anything that genuinely requires a re-install must land in `install.sh` or `post_install.sh` for the signal to fire.

### Bootstrap markers in user rc files

`setup_bootstrap` in `script/install.sh` writes a block bracketed by `# Begin dot-star bootstrap.` / `# End dot-star bootstrap.` into `~/.bash_profile` and `~/.bashrc`, removing any prior block first. If you change the bootstrap snippet, an existing user only picks it up by re-running `./install.sh`. Don't hand-edit those files in CI or scripts; round-trip through `setup_bootstrap`.

## Project conventions

- Shell style: prefer explicit `if` blocks over `&&`/`||` one-liners in functions; this is enforced in review (separate from `shfmt`, which only handles indentation).
- `set -x`, `set -euo pipefail`, and noisy `echo`s are common and intentional in installer / pruning scripts; keep them when editing those files.
- JSON files: alphabetize keys with `jq --sort-keys` when editing. Skip generated files (lockfiles, build artifacts, snapshots).
- Don't use `path` (or `fpath`/`manpath`/`cdpath`) as shell variable names: zsh ties them to `$PATH`/etc., so assignments silently clobber the real env var.
