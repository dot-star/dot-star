#!/bin/bash

if [ -t 1 -a -n "$DISPLAY" ]; then
    exec meld "$@"
else
    exec diff --unified "$@" | colordiff | less -R
fi
