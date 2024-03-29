# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Enable color in git.
git config --global color.ui true

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-colordiffltslotgt
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-color
git config --global color.diff.func magenta

# Use muted color for the file names.
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-colordiffltslotgt
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-color
git config --global color.diff.meta blue

if [[ "${OSTYPE}" == "darwin"* ]]; then
    # Install brew.
    command -v brew > /dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

    # Update: Removed setting bash as the default shell in favor of zsh.
    # Upgrade bash.
    # Fixes "-bash: shopt: autocd: invalid shell option name".
    # brew install bash
    # sudo bash -c "echo /usr/local/bin/bash >> /etc/shells"
    # chsh -s /usr/local/bin/bash
    # echo "${BASH_VERSION}"

    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/*.rb
    brew install colordiff
    brew install coreutils

    brew install diff-so-fancy
    git config --global --bool diff-so-fancy.markEmptyLines false
    git config --global --bool diff-so-fancy.stripLeadingSymbols false

    git config --global diff.tool opendiff
    git config --global difftool.prompt false

    brew install --cask google-cloud-sdk
    brew install --cask hammerspoon
    brew install bash-completion
    brew install blueutil
    brew install cmake
    brew install composer
    brew install diffutils
    brew install git
    brew install git-gui
    brew install grep
    brew install homebrew/dupes/rsync
    brew install macvim --HEAD

    brew install php@8.0
    brew link php@8.0

    brew install tree
    brew install wget

    # Install command-line fuzzy finder with key bindings and fuzzy completion.
    brew install fzf
    $(brew --prefix)/opt/fzf/install

    # Disable chime sound when power is connected.
    defaults write com.apple.PowerChime ChimeOnNoHardware -bool true

    # Show all files in Finder (requires a restart of Finder: `killall Finder').
    defaults write com.apple.Finder AppleShowAllFiles true

    # Disable Control-Command-D binding.
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 70 '<dict><key>enabled</key><false/></dict>'

    # Use diff highlight.
    ln -s "/usr/local/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" "/usr/local/bin/"

    # Use wildcard to run diff-highlight under the currently installed version of git.
    git config --global core.pager "${DOT_STAR_ROOT}/version_control/git_pager.sh"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get install colordiff
    sudo apt-get install fzf
    sudo apt-get install jq

    cd "/usr/share/doc/git/contrib/diff-highlight" &&
        sudo make &&
        sudo ln -v -s "/usr/share/doc/git/contrib/diff-highlight/diff-highlight" /usr/local/bin/

    # Use git's diff-highlight.
    git config --global core.pager "diff-highlight | less"
fi

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
