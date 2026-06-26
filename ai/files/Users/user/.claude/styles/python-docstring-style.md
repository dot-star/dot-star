# Python docstring style

## Defaults

- One-line is the default.
- Multi-line when one of these is true:
  - The contract has params/returns worth naming.
  - The behavior contrasts with a clear alternative.
  - The WHY is non-obvious (legacy compat, race, perf, hidden invariant).
  - Setup or environmental context needs explaining.
- Multi-line frame: `"""` opens on its own line, `"""` closes on its own line. Preserve an existing docstring's shape when editing: keep a multi-line frame multi-line (never collapse to a `"""text."""` one-liner, even if the new content fits on one line) and keep a one-liner one-line unless a multi-line trigger above now applies.
- Sentences end with periods.
- Use backticks inline for code references (`HelperClass`, `MODULE_CONSTANT`).
- Use `(e.g. ...)` for concrete examples in param descriptions and inline asides.
- Use parens for clarifying asides; never em dashes.
- Don't reference the current task, fix, PR, or bug being addressed; that belongs in the commit message or PR body and rots in the source.

## Test functions

One-line, ending in a period. Lead with the function under test by bare identifier, then the asserted behavior, then the condition.

```
"""Ensure <function> <does X> when <Y>."""
```

Examples:

```python
"""Ensure parse_iso8601 returns a tz-aware datetime when the input ends in Z."""

"""Ensure deactivate_user raises UserNotFoundError when the id is unknown."""

"""Ensure render_path returns the trailing-slashed form when strip_trailing is False."""
```

Some codebases use an older `Tests X.` / `Tests that X.` pattern. For new code, prefer `Ensure`: it names the unit, asserts the behavior, and qualifies the condition, all in one sentence.

Test docstrings must mirror the length and shape of existing test docstrings in the same file. Never embed the WHY for the change being tested; that's the production function's docstring's job.

## Test classes

One-line. Names the function or component under test, in backticks.

```python
"""Test the `parse_iso8601` function."""

"""Test the `RetryPolicy` class."""
```

For test classes that span more than one function, a topical phrase works:

```python
"""End-to-end locking behavior against the local container."""
```

## Function / method docstrings

One-line opener verb followed by the object, ending in a period.

| Verb | Example |
|---|---|
| `Returns` | `"""Returns the list of active worker ids for the given pool."""` |
| `Fetches` | `"""Fetches pending jobs that may have not completed successfully."""` |
| `Builds` / `Build` | `"""Builds a sectioned response body from a list of records."""` |
| `Handles` | `"""Handles enqueuing periodic jobs on the configured schedule."""` |
| `Creates` / `Create` | `"""Create the API gateway resource."""` |
| `Updates` | `"""Updates the user's profile from the latest source-of-truth data."""` |
| `Get` | `"""Get basic member information."""` |

## Multi-line function / method docstrings

Structure: lead summary line, blank line, body paragraph(s) explaining non-obvious WHAT/WHY, blank line, `:param:` / `:return:` / `:raises:` block. Param continuations indent four spaces under the param name. Each param description gets a concrete `e.g.` when it clarifies the contract.

```python
def build_response_sections(
    records: list[dict],
    group: Group,
    header_text: str,
    metadata: dict[str, dict],
    total_count: int,
    is_priority: bool,
) -> list[dict]:
    """
    Builds response sections for a list of records.

    Splits content across multiple sections when the rendered text would exceed
    `MAX_SECTION_CHAR_LIMIT`; the first section carries the header line and
    continuation sections omit it. The final section is truncated with a
    remaining-count footer when the full set would still overflow.

    :param records: Records to render. Returns `[]` when empty.
    :param group: Group the records belong to; used to build detail URLs
        (e.g. `GROUP_OPTIONS.alpha`).
    :param header_text: Section title rendered into the header line
        (e.g. "Ready to ship", "Pending review").
    :param metadata: Mapping of record id to metadata, used to append
        `| ref: <url|#123>` on pending-review lines.
    :param total_count: Total records across priority + standard sections,
        rendered in the priority header as `(<record_count>/<total_count>)`.
    :param is_priority: True renders the priority variant (✅, display name,
        no notification); False renders the standard variant (⏳, notification,
        detail link).
    :return: Response sections ready to append to a payload.
    """
```

## Class docstrings

One-line for most cases:

```python
"""Represents and tracks a queued background job."""

"""Configures the worker pool stack."""

"""Indicates that there is no diff between the `head` and `base` refs."""
```

Multi-line when the class needs a "how to use" or "what backs this" note.

## Module docstrings

Multi-line, narrative.

```python
"""
<One-line summary of the file's purpose.>

<Body: what's special, how it differs from siblings, non-obvious deps,
gotchas. Reference related files/commands with backticks.>
"""
```

Example:

```python
"""
Integration tests for the persistence layer against a real database.

These tests exercise the locking / conditional-write behavior that unit
tests cannot verify because they mock out the storage client. They run
against the local container started by `make run-testsuite-integration`.
"""
```

For scripts, include `Usage:` and `Example:` sections under their own indented headings.
