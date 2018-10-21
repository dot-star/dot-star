# Correct typos when using the `cd' command.
shopt -s cdspell

# Append to the history file, rather than overwriting it.
shopt -s histappend

# Match filename (globbing) in a case-insensitive fashion.
shopt -s nocaseglob

# Type only the directory name to change into the directory.
shopt -s autocd

# Use the text that has been typed as the prefix for searching up and down
# through commands in the history.
#
# Use the `bind' command here to enable this behaviour instead of specifying
# inside .inputrc as fzf causes the setting to be ignored.
#   .inputrc
#   "\e[B": history-search-forward
#   "\e[A": history-search-backward
#
#   $ bind -P | grep "history-search-"
#   history-search-backward is not bound to any keys
#   history-search-forward is not bound to any keys
if is_interactive_shell; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi
