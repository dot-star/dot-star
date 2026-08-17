# todo

- Automate permission triage: promote recurring requests from `~/.claude/permission-requests.jsonl` into the global allowlist without prompting. Replaces the removed `triage_nudge.sh` SessionStart nudge and `triage-permissions` skill (commit `90ffb8c`); ideally runs as a background agent off the logging ledger.
- Format and type-check Python with the ruff toolchain: replace the `black` pre-commit hook with `ruff-format` (`ruff-check` is already wired), select real lint rules under `[tool.ruff.lint]` in `pyproject.toml` starting with the annotation rules, and add a pinned `ty` hook scoped to the checked paths.
