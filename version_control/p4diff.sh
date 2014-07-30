#!/bin/bash

bash "$(dirname $0)/p4differ.sh" "${@}" | colordiff | less -R
