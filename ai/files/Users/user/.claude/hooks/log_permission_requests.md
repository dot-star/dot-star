# log_permission_requests

A `PermissionRequest` hook (no matcher, so every tool) that appends the
permissions a request needed to a growing JSON Lines file at
`~/.claude/permission-requests.jsonl`. Review that file later to decide which
rules to promote into a real allowlist by hand.

It only ever *appends* and prints nothing, so it never allows or denies; the
permission prompt is untouched.

## Entry shape

Each line is one valid, single-line standard JSON object (shown pretty-printed
here for readability):

```
{
  "permissions": {
    "allow": [
      "Bash(git check-ignore *)"
    ]
  },
  "metadata": {
    "timestamp": "2026-06-09T14:03:21.512-07:00",
    "tool_name": "Bash",
    "cwd": "/Users/user/Projects/foo",
    "settings_path": "/Users/user/Projects/foo/.claude/settings.local.json",
    "session_id": "463446f2-9c27-43fb-86ce-519915e12750"
  }
}
```

- `permissions.allow`: the rules Claude Code suggested for the call (its
  `permission_suggestions`). When the payload carries none, one rule is
  synthesized: `Bash(<command>)` for Bash, else the bare tool name.
- `metadata.settings_path`: the project-local settings file the request would be
  recorded in (`<cwd>/.claude/settings.local.json`), so the reviewer can see
  which project asked.

Entries are never deduplicated: the same request logs on every occurrence, so
frequency is visible in the file.

## JSON Lines on disk

The file is JSON Lines: one entry per line, each a self-contained standard JSON
object terminated by a newline. Appending only ever adds a line, so each request
diffs as pure added lines and no prior line is rewritten. Read it line by line
(e.g. `jq --compact-output . permission-requests.jsonl`), not as one array.

## Storage

`~/.claude/permission-requests.jsonl` is a real file in the real `~/.claude`
directory, outside the symlinked dot-star tree, so the accumulated runtime data
never lands in git. Appends take an exclusive `flock`, so concurrent sessions
do not corrupt the file.

## Testing

```
pytest log_permission_requests_test.py
python3 -m unittest log_permission_requests_test
```
