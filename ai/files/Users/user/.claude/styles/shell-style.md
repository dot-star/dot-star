# Shell style

Conventions for hand-written shell (bash, zsh) that go beyond what `shfmt` enforces.

## Blank lines around `if` blocks

Blank lines around `if` blocks track logical grouping. Keep an assignment flush with the `if` that consumes its result (`x="$(...)"` immediately above `if [[ -z "${x}" ]]; then`); same for consecutive assignments feeding the same conditional. Insert a blank line above standalone `if`s not fed by the previous line, after a closing `fi`, and after the function's `local` declaration block. A line-doc comment describing the `if` stays flush with it, so the blank line goes above the comment.

## Multi-line strings

Build a multi-line string so its source mirrors the rendered output: one append per output line, each carrying a literal `\n`, rather than packing every `\n` into a single `$'...'`.

Why: the source reads line-for-line like what the user sees, and a change to one output line touches one source line (clean diffs).

```
reason=$'Heading:\n\n'
reason+=$'\n┌─ first body line'
reason+=$'\n│ second body line'
reason+=$'\n└─ footer'
```

Not (the whole block collapsed onto one source line):

```
reason=$'Heading:\n\n\n┌─ first body line\n│ second body line\n└─ footer'
```

A `\n` mid-string is still fine (a header's trailing `\n\n` stays inline); the rule is about not flattening a multi-line block onto one source line.

## Pipelines

Break multi-stage pipelines across lines. Leave `|` at the end of the upstream line and put each downstream stage on its own line, indented one level under the start of the pipeline.

Why: each stage of a pipeline does a distinct thing; one-stage-per-line makes the transform visible and diffs cleaner when stages are added, removed, or reordered.

```
git diff --cached --color=always |
    truncate_long
```

```
git log --pretty=format:'%h %s' |
    grep --invert-match Merge |
    head --lines=20
```

Single-stage commands stay on one line; this only kicks in once a `|` is involved.

## Self-documenting command variables

When a command's or test's intent isn't obvious from its literal text, bind it to a descriptively-named local variable or predicate function so the call site reads as prose.

- `local is_valid_json="jq empty"` lets the conditional read `if $is_valid_json "${file}"; then`.
- A `has_shebang() { ... }` helper lets `if has_shebang; then` replace an inline `if [ "$(head -c2 "${f}")" = '#!' ]; then`.
- Prefer the prose-reading predicate even when it costs a small helper function: the "never single-line `if`" rule governs `if` bodies only and never argues against defining such a helper (give it a normal multi-line body).
- Skip when the literal command or test is already clear on its own.
