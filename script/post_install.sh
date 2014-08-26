# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Enable color in git.
git config --global color.ui true

wget https://raw.githubusercontent.com/git/git/master/contrib/diff-highlight/diff-highlight
sudo chmod +x diff-highlight
sudo mv diff-highlight /usr/bin/
git config --global core.pager "diff-highlight | less"

# Create backup and swap directories specified in vimrc.
mkdir -p "$HOME/.vim/backup/"
mkdir -p "$HOME/.vim/colors/"
mkdir -p "$HOME/.vim/swap/"

# Install vim themes.
if [ ! -L "${HOME}/.vim/colors/railscat.vim" ]; then
    ln -v -s "${DOT_STAR_ROOT}/vim/colors/railscat.vim" "${HOME}/.vim/colors/"
fi
if [ ! -L "${HOME}/.vim/colors/molokai.vim" ]; then
    ln -v -s "${DOT_STAR_ROOT}/vim/colors/molokai.vim" "${HOME}/.vim/colors/"
fi

# Configure vimrc.
if [ ! -e "${HOME}/.vimrc" ]; then
    ln -s -v "${DOT_STAR_ROOT}/vim/.vimrc" "${HOME}"
fi
