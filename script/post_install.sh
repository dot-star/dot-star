# Configure global gitignore.
[[ ! -L "${HOME}/.gitignore" ]] && ln -vs "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
git config --global core.excludesfile "~/.gitignore"
