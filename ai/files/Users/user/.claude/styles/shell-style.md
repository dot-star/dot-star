# Shell style

Conventions for hand-written shell (bash, zsh) that go beyond what `shfmt` enforces.

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
