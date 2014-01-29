# Use vim as the default editor.
export EDITOR="vim"
export VISUAL="vim"

# Use vi-style command line editing.
set -o vi

# Correct typos when using the `cd' command.
shopt -s cdspell

# Append to the history file, rather than overwriting it.
shopt -s histappend

# Match filename (globbing) in a case-insensitive fashion.
shopt -s nocaseglob

# Set default options for grep.
export GREP_OPTIONS="--binary-files=without-match"
