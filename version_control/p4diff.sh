#!/bin/bash


if [ -t 1 ]; then
  bash "$(dirname $0)/p4differ.sh" "${@}" | diff-highlight | colordiff | less -R
else
  bash "$(dirname $0)/p4differ.sh" "${@}"
fi
