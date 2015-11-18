#!/bin/bash

git pull

curl \
    --output version_control/git-completion.bash \
    --verbose \
    "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash"
