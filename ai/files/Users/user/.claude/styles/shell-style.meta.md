# Shell style



## Blank lines around `if` blocks



## Multi-flag invocations





```




```



```

```



## Quoted string arguments

Quotes mark the value as data, so it reads the way the same call reads from Python (`stage="dev"`, `run("rollback")`) rather than as a bare keyword or identifier. A positional word is the same data as a flag's value, so splitting the rule at the flag boundary left a mode argument like `"rollback"` looking like code beside its quoted neighbors. A quoted value also stays correct once it later grows a space or a glob character, where a bare one splits or expands without warning. The command name is the thing being called, not data handed to it, so it stays bare. A number can grow neither and reads as a number only when bare, so it stays unquoted.

```

```

```




```



```

```

```




```

Matches the multi-flag rule's scope: a typed one-off is never reread, so the quotes buy nothing there.

## Quoted glob literals

The quotes split the pattern at a glance into the part that matches itself and the wildcard doing the matching; a bare `*.meta.md` makes the reader check each character, since `.` is a wildcard in regex and a later `?` or `[` would silently start matching. It's the quoted-string rule above applied to patterns: the literal is data, so it gets the quotes data gets.

```

```



```

```

## Multi-line strings





```




```



```

```



## One declaration per `local`





```


```

```



```



```

```

```

```

## Pipelines





```


```

```



```



## One `jq` call per JSON input

Every `jq` call spawns a process and re-parses the whole payload, about 8 ms apiece measured on this laptop. A hook pays that on every event it fires on, so three reads where one would do cost every prompt about 16 ms for nothing. One call also reads stdin directly, which drops the `input=$(cat)` copy that per-field calls need because a pipe can only be read once.

```








```



```



```

- NUL is the only separator no value can collide with: a JSON string carries it only as an escaped `\u0000`, which `--raw-output0` refuses with an error rather than printing, so a field can never split in two. `--raw-output0` needs jq 1.7 or later.
- `// empty` is the natural default for a single read, which is why it survives a merge by copy-paste and silently shifts every field after a missing one.
- A chain spawns one process per stage for a transform jq can already compose inside one filter, the same fold as the `gh api --jq` rule in `CLAUDE.md`.

## Self-documenting command variables



-
-
-
-
