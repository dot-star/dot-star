# Ignore duplicate commands and commands that start with spaces.
export HISTCONTROL=ignoredups:ignorespace

# Increase size of bash history.
export HISTSIZE=32768
export HISTFILESIZE="${HISTSIZE}"

# Save each command in bash history right after it has been executed.
# Append the PROMPT_COMMAND variable (e.g. "; $PROMPT_COMMAND") after modifying
# PROMPT_COMMAND to avoid breaking PROMPT_COMMAND. Without doing this, new tabs
# won't retrain the current directory even with the Preferences > General > New
# tabs open with: Same Working Directory setting set.
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
