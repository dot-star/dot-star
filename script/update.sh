#!/bin/bash

git pull

curl \
    --silent \
    --output git/git-completion.bash \
    "https://raw.github.com/git/git/master/contrib/completion/git-completion.bash"
