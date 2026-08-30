# todo

- Automate permission triage: promote recurring requests from `~/.claude/permission-requests.jsonl` into the global allowlist without prompting. Replaces the removed `triage_nudge.sh` SessionStart nudge and `triage-permissions` skill (commit `90ffb8c`); ideally runs as a background agent off the logging ledger.
- Format Python with the ruff toolchain: replace the `black` pre-commit hook with `ruff-format` (`ruff-check` is already wired) and select real lint rules under `[tool.ruff.lint]` in `pyproject.toml`.
- Annotate the Python scripts a few files at a time, then select ruff's `ANN` rules in `pyproject.toml` to keep new code annotated. `ruff check --select ANN` reports 88 gaps today (49 `ANN201` missing return types, 39 `ANN001` missing argument types), 29 of them auto-fixable with `--unsafe-fixes`. The `ty` hook only verifies annotations that are already written, so annotations stay optional until `ANN` is on.
