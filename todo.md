# todo

- Automate permission triage: promote recurring requests from `~/.claude/permission-requests.jsonl` into the global allowlist without prompting. Replaces the removed `triage_nudge.sh` SessionStart nudge and `triage-permissions` skill (commit `90ffb8c`); ideally runs as a background agent off the logging ledger.
- Format Python with the ruff toolchain: replace the `black` pre-commit hook with `ruff-format` (`ruff-check` is already wired) and select real lint rules under `[tool.ruff.lint]` in `pyproject.toml`.
