# Shell style

Conventions for hand-written shell (bash, zsh) that go beyond what `shfmt` enforces.

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
