bt_push "pre-OS git config"
# Configure global gitignore.
ensure_symlink "${DOT_STAR_ROOT}/tools/version_control/.gitignore" "${HOME}/.gitignore"
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

# Set the upstream automatically on a new branch's first push, so a bare `git push` creates origin/<branch> instead of failing with "no upstream branch".
git config --global push.autoSetupRemote true
bt_pop

if [[ "${OSTYPE}" == "darwin"* ]]; then
    bt_push "darwin section"
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
        curl
        diff-so-fancy
        diffutils
        fzf
        git
        git-delta
        git-gui
        glow
        grep
        lazygit
        php@8.4
        # Provide `pdftoppm` and `pdfinfo`, which Claude Code shells out to when reading a PDF.
        poppler
        pyenv
        pyenv-virtualenv
        rsync
        tig
        tree
        wget
    )
    casks=(
        google-cloud-sdk
        hammerspoon
    )

    bt_push "presence checks"
    # Cache installed names with one fork each instead of forking
    # `brew list --versions --formula <name>` per item (~370ms each).
    installed_formulae="$(brew list --formula)"
    installed_casks="$(brew list --cask)"
    is_installed="grep --line-regexp --quiet --fixed-strings"

    # Skip what's already installed so brew (and its auto-update) only runs when
    # there's real work to do.
    missing_formulae=()
    for formula in "${formulae[@]}"; do
        if ! $is_installed "${formula}" <<<"${installed_formulae}"; then
            missing_formulae+=("${formula}")
        fi
    done

    missing_casks=()
    for cask in "${casks[@]}"; do
        if ! $is_installed "${cask}" <<<"${installed_casks}"; then
            missing_casks+=("${cask}")
        fi
    done
    bt_pop

    bt_push "fetch dispatch (bg)"
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
    bt_pop

    bt_push "macvim --HEAD"
    # `macvim --HEAD` can't share a batch (the flag would apply to every formula).
    if ! $is_installed macvim <<<"${installed_formulae}"; then
        brew install macvim --HEAD
    fi
    bt_pop

    bt_push "diff tool git config"
    git config --global diff.tool opendiff
    git config --global difftool.prompt false
    git config --global --bool diff-so-fancy.markEmptyLines false
    git config --global --bool diff-so-fancy.stripLeadingSymbols false
    bt_pop

    bt_push "wait + install"
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
    bt_pop

    bt_push "post-install hooks"

    # TODO: Gate the fzf install hook on `[ -f ~/.fzf.bash ]` plus a grep that
    # the `~/.bashrc` snippet is already present (~700ms wasted per re-run).

    brew_prefix="$(brew --prefix)"

    # Report whether the installed keg is the one currently linked. Homebrew
    # records the linked keg as a symlink under `var/homebrew/linked/<formula>`,
    # so this costs no fork; re-running `brew link` on an already-linked keg only
    # prints an "Already linked" warning.
    is_linked() {
        local formula="${1}"
        local linked_keg="${brew_prefix}/var/homebrew/linked/${formula}"
        if [ ! -e "${linked_keg}" ]; then
            return 1
        fi

        # Compare inodes so an upgraded-but-unlinked keg still relinks.
        [ "${linked_keg}" -ef "${brew_prefix}/opt/${formula}" ]
    }

    # curl is keg-only; force-link so the Homebrew build wins over /usr/bin/curl.
    if ! is_linked curl; then
        brew link --force --overwrite curl
    fi

    # `--overwrite` takes the `bin/pear` symlink from any older php@N keg
    # that currently owns it (php@8.0, in practice).
    if ! is_linked php@8.4; then
        brew link --overwrite php@8.4
    fi

    # Install fzf key bindings and fuzzy completion.
    "$(brew --prefix)/opt/fzf/install" --all
    bt_pop

    bt_push "macOS defaults"
    # Disable chime sound when power is connected.
    defaults write com.apple.PowerChime ChimeOnNoHardware -bool true

    # Show all files in Finder (requires a restart of Finder: `killall Finder').
    defaults write com.apple.Finder AppleShowAllFiles true

    # Disable Control-Command-D binding.
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 70 '<dict><key>enabled</key><false/></dict>'
    bt_pop

    bt_push "diff-highlight ln"
    # Use diff highlight.
    homebrew_prefix="${HOMEBREW_PREFIX:-/usr/local}"
    diff_highlight_src="${homebrew_prefix}/share/git-core/contrib/diff-highlight/diff-highlight"
    diff_highlight_dst="${homebrew_prefix}/bin/diff-highlight"
    if [ -e "${diff_highlight_src}" ]; then
        ln -sf "${diff_highlight_src}" "${diff_highlight_dst}"
    fi
    bt_pop
    bt_pop # darwin section
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    bt_push "linux section"
    # Package is `bat' on Debian/Ubuntu but installs the binary as `batcat'
    # to avoid clashing with an unrelated `bat' package.
    apt_packages=(
        bat
        colordiff
        fzf
        git-delta
        jq
        tig
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
    bt_pop # linux section
fi

bt_push "pip packages"
# Install Python packages for the shell's `python3`, on every platform. Take
# pandas with its `excel` extra: pandas ships no spreadsheet reader of its own,
# so a bare install raises ImportError from `read_excel`, and the extra is what
# pulls in openpyxl for `.xlsx` alongside the engines for the other formats.
pip_packages=(
    "pandas[excel]"
)

# Install into the per-user site directory. Homebrew and Debian both mark their
# Python externally managed, which makes a plain install refuse outright;
# `--user` writes to `~/Library/Python/<ver>` (or `~/.local`) instead, keeping
# the packages clear of the managed prefix that the override alone would touch.
#
# Let pip do the presence check rather than pre-filtering the way brew and apt
# do above. An already-satisfied run resolves locally in under half a second and
# never reaches the network, so a re-install stays cheap.
if ! python3 -m pip install --user --break-system-packages --quiet "${pip_packages[@]}"; then
    # Quote each spec so a copy-pasted retry survives zsh globbing the `[extra]` brackets.
    printf -v quoted_pip_packages "'%s' " "${pip_packages[@]}"
    warn "Failed to install Python packages: ${pip_packages[*]}" "python3 -m pip install --user --break-system-packages ${quoted_pip_packages}"
fi
bt_pop

bt_push "git-delta config"
# Use delta as git's pager via the repo wrapper.
git config --global core.pager "${DOT_STAR_ROOT}/tools/version_control/git_pager.sh"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.keep-plus-minus-markers true
git config --global delta.line-numbers false
git config --global delta.navigate true

# Install a Monokai variant that lightens only the comment color. delta reads syntax themes from bat's cache; stock Monokai comments are a dim olive that the bright `+`/`-` backgrounds below swallow whole. Ubuntu ships the binary as `batcat`.
bat_bin="bat"
if ! command -v bat >/dev/null 2>&1; then
    bat_bin="batcat"
fi

bat_themes_dir="$("${bat_bin}" --config-dir)/themes"
mkdir -p "${bat_themes_dir}"
ensure_symlink "${DOT_STAR_ROOT}/tools/version_control/monokai-extended-readable-comments.tmTheme" "${bat_themes_dir}/monokai-extended-readable-comments.tmTheme"
"${bat_bin}" cache --build

# Bright added/removed-line backgrounds so `+`/`-` lines stand apart from context; the readable-comments theme keeps the syntax-highlighted comment text legible on them.
git config --global delta.syntax-theme "monokai-extended-readable-comments"
git config --global delta.minus-style "syntax #800000"
git config --global delta.plus-style "syntax #008000"
bt_pop

bt_push "vim setup"
# Create backup and swap directories specified in vimrc.
mkdir -p "$HOME/.vim/backup/"
mkdir -p "$HOME/.vim/colors/"
mkdir -p "$HOME/.vim/swap/"

# Install vim themes.
ensure_symlink "${DOT_STAR_ROOT}/tools/vim/colors/railscat.vim" "${HOME}/.vim/colors/railscat.vim"
ensure_symlink "${DOT_STAR_ROOT}/tools/vim/colors/molokai.vim" "${HOME}/.vim/colors/molokai.vim"

# Configure vimrc.
ensure_symlink "${DOT_STAR_ROOT}/tools/vim/.vimrc" "${HOME}/.vimrc"

ensure_symlink "${DOT_STAR_ROOT}/tools/bash/.jshintrc" "${HOME}/.jshintrc"
bt_pop # vim setup
