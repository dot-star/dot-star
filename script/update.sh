#!/bin/bash

git pull

curl \
    --fail \
    --output tools/version_control/git-completion.bash \
    --verbose \
    "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash"

if [[ "${OSTYPE}" == "darwin"* ]]; then
    brew upgrade
fi
