# Configure global gitignore.
[[ ! -e "${HOME}/.gitignore" ]] && ln -vs "${DOT_STAR_ROOT}/git/.gitignore" "${HOME}"
git config --global core.excludesfile "~/.gitignore"
