#!/usr/bin/env bash

CWD="${PWD}"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}"
cd ..
source "bash/.aliases.sh"
source "bash/.behavior.sh"
source "bash/.cd.sh"
source "bash/.history.sh"
source "bash/.path.sh"
source "bash/.prompt.sh"
source "brew/.aliases.sh"
source "coffeescript/.aliases.sh"
source "django/.aliases.sh"
source "lynx/.aliases.sh"
source "sass/.aliases.sh"
source "ssh/.aliases.sh"
source "vim/.aliases.sh"
source "version_control/.aliases.sh"
source "virtualenv/.aliases.sh"
source "bash/.extra.sh"
\cd "${CWD}"
if $ssh; then
    if [ -z "${BYOBU_WINDOW_NAME}" ]; then
        if which "byobu" &> /dev/null; then
            byobu
        fi
    fi
fi
