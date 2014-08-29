#!/bin/bash

bash "$(dirname $0)/p4differ.sh" "${@}" | diff-highlight | colordiff | less -R
