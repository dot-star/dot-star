#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}"
cd ..
source "bash/.behavior.sh"
source "bash/.cd.sh"
source "bash/.extra.sh"
source "bash/.history.sh"
source "bash/.path.sh"
source "bash/.prompt.sh"
source "bash/.shortcuts.sh"
source "brew/.aliases.sh"
source "django/.aliases.sh"
source "git/.aliases.sh"
source "ssh/.aliases.sh"
source "vim/.aliases.sh"
source "virtualenv/.aliases.sh"
