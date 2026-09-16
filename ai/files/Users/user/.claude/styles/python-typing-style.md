# Python typing style

Annotate every function and method: each parameter and the return type, on every `def` written or touched. No "obvious enough to skip" case: a one-line private helper, a `main()`, and a test method all take annotations. Bare `self` and `cls` stay bare.

## Defaults

- Every parameter gets a type; `*args` and `**kwargs` too (`*args: str`, `**kwargs: Any`).
- Every function gets a return type. A function with no `return` is `-> None`; a test method is `-> None`. Leaving the return off reads as "forgot", not as "returns nothing".
- Write `-> NoReturn` on a function that always raises or exits.
- Use the modern builtin spellings, never the `typing` aliases: `list[str]`, `dict[str, int]`, `tuple[int, ...]`, `set[str]`, `type[Foo]`, `str | None`. `typing.List`, `typing.Dict`, `typing.Optional`, `typing.Union` are out.
- Skip `from __future__ import annotations`; the pinned interpreter (`.python-version`) already reads the modern syntax at runtime.
- Import the abstract shapes from `collections.abc`, not `typing`: `Iterable`, `Iterator`, `Callable`, `Mapping`, `Sequence`.
- Accept the broad shape and return the concrete one: take `Iterable[str]` or `Mapping[str, str]` where any will do; return `list[str]` or `dict[str, str]`, the thing actually built.
- Reach for `Any` only at a genuine boundary (a parsed JSON payload, an untyped third-party return) and say why in the docstring's `:param:` line. An `Any` that spares the writer a lookup is the one `ty` can't catch.
- Annotate a module-level constant or a class attribute only when the assigned literal doesn't already say the type: `TIMEOUT_SECONDS = 30` stays bare, `pending: list[Job] = []` carries the type its empty literal can't.

## Touched code self-heals

Editing a `def` that has no annotations means adding them as part of the edit, per the self-healing rule in `CLAUDE.md`. Annotate the whole signature, not just the parameter the change touched; a half-annotated signature reads as two authors disagreeing. Land the annotation swap as its own atomic commit when the edit is otherwise unrelated.

## Example

```python
from collections.abc import Iterable


def render_rows(rows: Iterable[dict[str, str]], width: int = 80) -> list[str]:
    """
    Renders each row as a fixed-width line.

    :param rows: Rows to render, one mapping per line.
    :param width: Column width the line is padded to.
    :return: Rendered lines, one per row.
    """
    lines: list[str] = []
    for row in rows:
        lines.append(" ".join(row.values()).ljust(width))
    return lines
```
