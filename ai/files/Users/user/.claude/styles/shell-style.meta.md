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



## Self-documenting command variables



-
-
-
-
