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

    # Upgrade bash.
    # Fixes "-bash: shopt: autocd: invalid shell option name".
    brew install bash
    sudo bash -c "echo /usr/local/bin/bash >> /etc/shells"
    chsh -s /usr/local/bin/bash
    echo "${BASH_VERSION}"

    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/*.rb
    brew install colordiff
    brew install coreutils

    brew install diff-so-fancy
    git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
    git config --global --bool diff-so-fancy.markEmptyLines false
    git config --global --bool diff-so-fancy.stripLeadingSymbols false

    git config --global diff.tool opendiff
    git config --global difftool.prompt false

    brew install bash-completion
    brew install cmake
    brew install diffutils
    brew install git
    brew install grep --with-default-names
    brew install homebrew/dupes/rsync
    brew install macvim --with-override-system-vim
    brew install tree
    brew install wget

    # Install command-line fuzzy finder with key bindings and fuzzy completion.
    brew install fzf
    $(brew --prefix)/opt/fzf/install

    # Disable chime sound when power is connected.
    defaults write com.apple.PowerChime ChimeOnNoHardware -bool true
else
    sudo apt-get install colordiff
fi

# Use diff highlight.
ln -s "/usr/local/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" "/usr/local/bin/"

# Use wildcard to run diff-highlight under the currently installed version of git.
git config --global core.pager '"/usr/local/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" | less -m'

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
