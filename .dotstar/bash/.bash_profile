#!/usr/bin/env bash

echo "bash profile"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}"
cd ..
source "bash/.behavior.sh"
source "bash/.cd.sh"
source "bash/.prompt.sh"
source "bash/.shortcuts.sh"
source "brew/.aliases.sh"
source "django/.aliases.sh"
source "git/.aliases.sh"
source "vim/.aliases.sh"
source "virtualenv/.aliases.sh"
