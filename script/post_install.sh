# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Enable color in git.
git config --global color.ui true

if [[ "${OSTYPE}" == "darwin"* ]]; then
    # Install brew.
    command -v brew > /dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/*.rb
    brew install colordiff
    brew install coreutils

    brew install diff-so-fancy
    git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
    git config --global --bool diff-so-fancy.markEmptyLines false
    git config --global --bool diff-so-fancy.stripLeadingSymbols false

    brew install diffutils
    brew install git
    brew install grep --with-default-names
    brew install homebrew/dupes/rsync
    brew install macvim --with-override-system-vim
    brew install wget

    # Install command-line fuzzy finder with key bindings and fuzzy completion.
    brew install fzf
    $(brew --prefix)/opt/fzf/install
fi

# Install diff highlight.
wget https://raw.githubusercontent.com/git/git/master/contrib/diff-highlight/diff-highlight
sudo chmod +x diff-highlight
sudo mv diff-highlight /usr/local/bin/
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

ln -s -v "${DOT_STAR_ROOT}/bash/.jshintrc" "${HOME}"
