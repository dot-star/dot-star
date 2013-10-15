# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Create backup and swap directories specified in vimrc.
mkdir --parents "$HOME/.vim/backup/"
mkdir --parents "$HOME/.vim/swap/"

# Configure vimrc.
if [ ! -e "${HOME}/.vimrc" ]; then
    ln -s -v "${DOT_STAR_ROOT}/vim/.vimrc" "${HOME}"
fi
