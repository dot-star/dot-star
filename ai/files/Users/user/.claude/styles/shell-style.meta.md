# Shell style



## Blank lines around `if` blocks



## Multi-flag invocations





```




```



```

```



## Quoted flag values

Quotes mark the value as data, so it reads the way the same call reads from Python (`stage="dev"`) rather than as a bare keyword or identifier. A quoted value also stays correct once it later grows a space or a glob character, where a bare one splits or expands without warning. A number can grow neither and reads as a number only when bare, so it stays unquoted.

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
