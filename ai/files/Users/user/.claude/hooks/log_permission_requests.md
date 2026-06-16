# log_permission_requests

A `PermissionRequest` hook (no matcher, so every tool) that appends the
permissions a request needed to a growing array at
`~/.claude/permission-requests.json`. Review that file later to decide which
rules to promote into a real allowlist by hand.

It only ever *appends* and prints nothing, so it never allows or denies; the
permission prompt is untouched.

## Entry shape

```
{
  "permissions": {
    "allow": [
      "Bash(git check-ignore *)"
    ],
  },
  "metadata": {
    "timestamp": "2026-06-09T14:03:21.512-07:00",
    "tool_name": "Bash",
    "cwd": "/Users/user/Projects/foo",
    "settings_path": "/Users/user/Projects/foo/.claude/settings.local.json",
    "session_id": "463446f2-9c27-43fb-86ce-519915e12750",
  },
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

## Relaxed form on disk

The file carries a trailing comma after every object member (a form strict JSON
rejects), so each appended entry diffs as pure added lines. The hook strips those
trailing commas before parsing on the next append, so the read-append cycle still
round-trips; review it with a trailing-comma-tolerant reader.

## Storage

`~/.claude/permission-requests.json` is a real file in the real `~/.claude`
directory, outside the symlinked dot-star tree, so the accumulated runtime data
never lands in git. Appends take an exclusive `flock`, so concurrent sessions
do not corrupt the array.

## Testing

```
pytest log_permission_requests_test.py
python3 -m unittest log_permission_requests_test
```
