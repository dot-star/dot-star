# Configure global gitignore.
[[ ! -e "${HOME}/.gitignore" ]] && ln -vs "${DOT_STAR_ROOT}/git/.gitignore" "${HOME}"
git config --global core.excludesfile "~/.gitignore"

# Configure vimrc.
if [ ! -e "${HOME}/.vimrc" ]; then
    ln -s -v "${DOT_STAR_ROOT}/vim/.vimrc" "${HOME}"
fi
