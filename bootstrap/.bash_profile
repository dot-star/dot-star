#!/usr/bin/env bash

CWD="${PWD}"

if [[ -n "${BASH_VERSION}" ]]; then
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION}" ]]; then
    DIR="$(dirname $0)"
fi

cd "${DIR}"
cd ..

# source "tools/bash/.timer.sh"

source "tools/bash/.config.sh"
source "tools/bash/.requires.sh"
source "tools/bash/.confirm_prompts.sh"
source "tools/bash/.aliases.sh"
source "tools/zsh/.aliases.sh"

if [[ -n "${BASH_VERSION}" ]]; then
    source "tools/bash/.behavior.sh"
fi

source "ai/.aliases.sh"
source "tools/bash/.cd.sh"
source "tools/bash/.data_analysis.sh"
source "tools/bash/.data_transform.sh"
source "tools/bash/.history.sh"
source "tools/bash/.path.sh"
source "tools/bash/.pomodoro.sh"

if [[ -n "${BASH_VERSION}" ]]; then
    source "tools/bash/.prompt.sh"
fi

source "tools/bash/.safer_rm.sh"
source "tools/bat/.aliases.sh"
source "tools/brew/.aliases.sh"
source "tools/coffeescript/.aliases.sh"
source "tools/django/.aliases.sh"
source "tools/docker/.aliases.sh"
source "tools/glow/.aliases.sh"
source "tools/lazygit/.aliases.sh"
source "tools/lynx/.aliases.sh"
source "tools/node/.aliases.sh"
source "tools/php/.aliases.sh"
source "tools/python/.aliases.sh"
source "tools/sass/.aliases.sh"
source "tools/ssh/.aliases.sh"
source "tools/vim/.aliases.sh"
source "tools/version_control/.aliases.sh"
source "tools/virtualenv/.aliases.sh"
source "tools/quilt/.aliases.sh"
source "tools/bash/.conditionals.sh"
source "tools/bash/.settings.sh"
source "tools/bash/.extra.sh"
source "tools/bash/.install_check.sh"
\cd "${CWD}"
if is_ssh; then
    if [[ -z "${BYOBU_WINDOW_NAME}" ]]; then
        if which "byobu" &>/dev/null; then
            byobu
        fi
    fi
fi
