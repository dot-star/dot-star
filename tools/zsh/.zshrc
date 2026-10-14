#!/usr/bin/env zsh
# Record when this file started loading; the startup timer near the end measures the gap to the first prompt.
zmodload zsh/datetime
typeset -g zsh_startup_start=$EPOCHREALTIME

zstyle ':omz:update' mode auto

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"
ZSH_THEME="kennethreitz"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Begin dot-star zsh prompt.
zstyle ':omz:alpha:lib:git' async-prompt no
# End dot-star zsh prompt.

# Give login and non-login shells the same fpath; oh-my-zsh rebuilds its completion dump whenever fpath changes.
typeset -U fpath
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# Drop oh-my-zsh's dirs inherited through FPATH (brew shellenv exports it), so oh-my-zsh re-adds them in a fresh tab's order.
# Keep fpath identical in nested shells; any reorder invalidates the shared completion dump and forces a full rebuild.
fpath=(${fpath:#${ZSH}/*})

# Load this device's pre-oh-my-zsh overrides, so it can change ZSH_THEME and plugins.
if [[ -r ~/.zshrc.pre.local ]]; then
    source ~/.zshrc.pre.local
fi

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Source a tool's generated init script from a cache, so startup skips running the tool.
# Key the cache on the binary's resolved path and arguments; a Homebrew upgrade changes the path.
source_cached_init() {
    local name="$1"
    shift
    local binary="${commands[$1]}"
    local cache_file="${XDG_CACHE_HOME:-${HOME}/.cache}/dot-star/${name}.zsh"
    local cache_key
    local cached_key=""

    if [[ -z "${binary}" ]]; then
        return 1
    fi

    cache_key="# ${binary:A} ${*:2}"
    if [[ -r "${cache_file}" ]]; then
        read -r cached_key <"${cache_file}"
    fi

    if [[ "${cached_key}" != "${cache_key}" ]]; then
        mkdir -p "${cache_file:h}"

        # Write to a per-shell temp file, so tabs opening at once never source a half-written cache.
        if ! {
            print -r -- "${cache_key}"
            "$@"
        } >"${cache_file}.$$"; then
            rm -f "${cache_file}.$$"
            return 1
        fi
        mv -f "${cache_file}.$$" "${cache_file}"
    fi
    source "${cache_file}"
}

# Gate on ~/.fzf.zsh, the fzf installer's output; the installer also skips re-adding its source line while this path appears here.
if [[ -f ~/.fzf.zsh ]]; then
    source_cached_init fzf fzf --zsh
fi

# Begin dot-star bootstrap.
[[ -r ~/.dot-star/bootstrap/.bash_profile ]] && source ~/.dot-star/bootstrap/.bash_profile
# End dot-star bootstrap.

export NVM_DIR="$HOME/.nvm"

# Put the default alias's newest install on PATH without loading nvm, so the lazy loader can skip `nvm use`.
if [[ -r "${NVM_DIR}/alias/default" ]]; then
    nvm_default_bin=("${NVM_DIR}"/versions/node/v$(<"${NVM_DIR}/alias/default")*/bin(Nn[-1]))
    if [[ -n "${nvm_default_bin}" ]]; then
        export PATH="${nvm_default_bin}:${PATH}"
    fi
    unset nvm_default_bin
fi

# Update(Jan 2026): Nvm is now lazy loaded via the alias in "node/.aliases.sh".
# The following line has been commented out and moved to the alias:
# [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"

# eval "$(pyenv init --path)"
# eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"

# Added by Antigravity CLI installer
export PATH="/Users/user/.local/bin:$PATH"

# Open a Claude window investigating a slow start, then hand focus back to this window.
zsh_startup_investigate() {
    local elapsed_ms="$1"
    local login_shell="no"
    local parent_process
    local task

    # Capture how this shell started; the slowest cause so far only hit shells nested in another shell.
    if [[ -o login ]]; then
        login_shell="yes"
    fi
    parent_process="$(ps -o comm= -p "${PPID}")"
    task="zsh startup took ${elapsed_ms} ms before the first prompt."
    task+=" SHLVL=${SHLVL}, login shell: ${login_shell}, parent process: ${parent_process}, cwd: ${PWD}."
    task+=" Find what made this start slow and propose a fix."
    ~/.dot-star/ai/claude/open_investigation_window.sh \
        zsh_startup \
        "Investigate slow zsh startup" \
        "${task}"
}

# Print the gap between shell start and first prompt, once per interactive shell.
zsh_startup_report() {
    # Warn once the wait is noticeable before typing, alert once it feels sluggish.
    local warn_ms=500
    local alert_ms=1000
    local end=$EPOCHREALTIME
    local -i elapsed_ms
    local color=""
    local marker=""
    local limit=""
    local reset=""
    local note=""
    if [[ -n "${zsh_startup_start}" ]]; then
        elapsed_ms=$(((end - zsh_startup_start) * 1000))

        # Flag the gap the way the statusline flags context size: bare when healthy, budgeted against the alert mark past warn.
        if ((elapsed_ms >= alert_ms)); then
            color=$'\e[1;31m'
            marker="🚨"
            limit="/${alert_ms}"
            reset=$'\e[0m'
        elif ((elapsed_ms >= warn_ms)); then
            color=$'\e[33m'
            marker="⚠️"
            limit="/${alert_ms}"
            reset=$'\e[0m'
        fi

        if ((elapsed_ms >= warn_ms)); then
            if zsh_startup_investigate "${elapsed_ms}"; then
                note=" · opening investigation window"
            fi
        fi
        printf '%s%s%d%s ms%s%s\n' \
            "${color}" \
            "${marker}" \
            "${elapsed_ms}" \
            "${limit}" \
            "${reset}" \
            "${note}"
    fi
    add-zsh-hook -d precmd zsh_startup_report
    unfunction zsh_startup_report
    unfunction zsh_startup_investigate
    unset zsh_startup_start
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd zsh_startup_report

# Load this device's overrides last, so its PATH, variables and aliases win.
if [[ -r ~/.zshrc.post.local ]]; then
    source ~/.zshrc.post.local
fi
