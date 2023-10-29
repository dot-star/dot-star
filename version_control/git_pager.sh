homebrew_prefix="${HOMEBREW_PREFIX}"
if [[ -z "${HOMEBREW_PREFIX}" ]]; then
    homebrew_prefix="/usr/local"
fi

"${homebrew_prefix}/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" | \
    less --long-prompt
