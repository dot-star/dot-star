# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Create backup and swap directories specified in vimrc.
mkdir -p "$HOME/.vim/backup/"
mkdir -p "$HOME/.vim/colors/"
mkdir -p "$HOME/.vim/swap/"

# Install vim theme.
if [ ! -L "${HOME}/.vim/colors/railscat.vim" ]; then
    ln -v -s "${DOT_STAR_ROOT}/vim/colors/railscat.vim" "${HOME}/.vim/colors/"
fi

# Configure vimrc.
if [ ! -e "${HOME}/.vimrc" ]; then
    ln -s -v "${DOT_STAR_ROOT}/vim/.vimrc" "${HOME}"
fi
