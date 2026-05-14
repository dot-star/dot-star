# Configure global gitignore.
if [ ! -e "${HOME}/.gitignore" ]; then
    ln -s -v "${DOT_STAR_ROOT}/version_control/.gitignore" "${HOME}"
fi
git config --global core.excludesfile "~/.gitignore"

# Enable color in git.
git config --global color.ui true

# Suppress the "(use ...)" hint lines in `git status` output.
git config --global advice.statusHints false

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-colordiffltslotgt
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-color
git config --global color.diff.func magenta

# Use muted color for the file names.
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-colordiffltslotgt
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-color
git config --global color.diff.meta blue

# Colorize the branch name in long-form `git status` ("On branch X").
# https://git-scm.com/docs/git-config#Documentation/git-config.txt-colorstatusltslotgt
git config --global color.status.branch "yellow bold"

if [[ "${OSTYPE}" == "darwin"* ]]; then
    # Install brew.
    if ! command -v brew >/dev/null; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    # Update: Removed setting bash as the default shell in favor of zsh.
    # Upgrade bash.
    # Fixes "-bash: shopt: autocd: invalid shell option name".
    # brew install bash
    # sudo bash -c "echo /usr/local/bin/bash >> /etc/shells"
    # chsh -s /usr/local/bin/bash
    # echo "${BASH_VERSION}"

    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/*.rb
    formulae=(
        bash-completion
        bat
        blueutil
        cmake
        colordiff
        composer
        coreutils
        diff-so-fancy
        diffutils
        fzf
        git
        git-delta
        git-gui
        glow
        grep
        php@8.4
        rsync
        tree
        wget
    )
    casks=(
        google-cloud-sdk
        hammerspoon
    )

    # Skip what's already installed so brew (and its auto-update) only runs when
    # there's real work to do.
    missing_formulae=()
    for formula in "${formulae[@]}"; do
        if ! brew list --versions --formula "${formula}" >/dev/null 2>&1; then
            missing_formulae+=("${formula}")
        fi
    done

    missing_casks=()
    for cask in "${casks[@]}"; do
        if ! brew list --versions --cask "${cask}" >/dev/null 2>&1; then
            missing_casks+=("${cask}")
        fi
    done

    # Prefetch in the background while the rest of post_install runs.
    fetch_pids=()
    if [[ ${#missing_formulae[@]} -gt 0 ]]; then
        brew fetch --formula "${missing_formulae[@]}" &
        fetch_pids+=("$!")
    fi
    if [[ ${#missing_casks[@]} -gt 0 ]]; then
        brew fetch --cask "${missing_casks[@]}" &
        fetch_pids+=("$!")
    fi

    # `macvim --HEAD` can't share a batch (the flag would apply to every formula).
    if ! brew list --versions --formula macvim >/dev/null 2>&1; then
        brew install macvim --HEAD
    fi

    git config --global diff.tool opendiff
    git config --global difftool.prompt false
    git config --global --bool diff-so-fancy.markEmptyLines false
    git config --global --bool diff-so-fancy.stripLeadingSymbols false

    # Wait for prefetch, then install in one shot per kind.
    if [[ ${#fetch_pids[@]} -gt 0 ]]; then
        wait "${fetch_pids[@]}"
    fi
    if [[ ${#missing_formulae[@]} -gt 0 ]]; then
        brew install "${missing_formulae[@]}"
    fi
    if [[ ${#missing_casks[@]} -gt 0 ]]; then
        brew install --cask "${missing_casks[@]}"
    fi

    brew link php@8.4

    # Install fzf key bindings and fuzzy completion.
    "$(brew --prefix)/opt/fzf/install" --all

    # Disable chime sound when power is connected.
    defaults write com.apple.PowerChime ChimeOnNoHardware -bool true

    # Show all files in Finder (requires a restart of Finder: `killall Finder').
    defaults write com.apple.Finder AppleShowAllFiles true

    # Disable Control-Command-D binding.
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 70 '<dict><key>enabled</key><false/></dict>'

    # Use diff highlight.
    ln -s "/usr/local/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" "/usr/local/bin/"
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    # Package is `bat' on Debian/Ubuntu but installs the binary as `batcat'
    # to avoid clashing with an unrelated `bat' package.
    apt_packages=(
        bat
        colordiff
        fzf
        git-delta
        jq
    )

    missing_apt=()
    for pkg in "${apt_packages[@]}"; do
        if ! dpkg --status "${pkg}" >/dev/null 2>&1; then
            missing_apt+=("${pkg}")
        fi
    done

    if [[ ${#missing_apt[@]} -gt 0 ]]; then
        sudo apt-get install "${missing_apt[@]}"
    fi

    cd "/usr/share/doc/git/contrib/diff-highlight" &&
        sudo make &&
        sudo ln -v -s "/usr/share/doc/git/contrib/diff-highlight/diff-highlight" /usr/local/bin/
fi

# Use delta as git's pager via the repo wrapper.
git config --global core.pager "${DOT_STAR_ROOT}/version_control/git_pager.sh"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true

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

if [ ! -e "${HOME}/.jshintrc" ]; then
    ln -s -v "${DOT_STAR_ROOT}/bash/.jshintrc" "${HOME}"
fi
