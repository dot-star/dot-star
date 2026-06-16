# todo

- Automate permission triage: promote recurring requests from `~/.claude/permission-requests.jsonl` into the global allowlist without prompting. Replaces the removed `triage_nudge.sh` SessionStart nudge and `triage-permissions` skill (commit `90ffb8c`); ideally runs as a background agent off the logging ledger.
