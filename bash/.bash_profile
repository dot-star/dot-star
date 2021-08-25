#!/usr/bin/env bash

CWD="${PWD}"

if [[ -n "${BASH_VERSION}" ]]; then
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
elif [ -n "${ZSH_VERSION}" ]; then
  DIR="$(dirname $0)"
fi

cd "${DIR}"
cd ..
source "bash/.aliases.sh"

if [ -n "${BASH_VERSION}" ]; then
  source "bash/.behavior.sh"
fi

source "bash/.cd.sh"
source "bash/.history.sh"
source "bash/.path.sh"
source "bash/.pomodoro.sh"

if [[ -n "${BASH_VERSION}" ]]; then
  source "bash/.prompt.sh"
fi

source "bash/.safer_rm.sh"
source "brew/.aliases.sh"
source "coffeescript/.aliases.sh"
source "django/.aliases.sh"
source "docker/.aliases.sh"
source "lynx/.aliases.sh"
source "sass/.aliases.sh"
source "ssh/.aliases.sh"
source "vim/.aliases.sh"
source "version_control/.aliases.sh"
source "virtualenv/.aliases.sh"
source "quilt/.aliases.sh"
source "bash/.settings.sh"
source "bash/.extra.sh"
\cd "${CWD}"
if is_ssh; then
    if [ -z "${BYOBU_WINDOW_NAME}" ]; then
        if which "byobu" &> /dev/null; then
            byobu
        fi
    fi
fi
