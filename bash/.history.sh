# Ignore duplicate commands and commands that start with spaces.
export HISTCONTROL=ignoredups:ignorespace

# Increase size of bash history.
export HISTSIZE=32768
export HISTFILESIZE="${HISTSIZE}"

# Save each command in bash history right after it has been executed.
PROMPT_COMMAND='history -a'
