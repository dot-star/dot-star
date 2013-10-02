# Vim aliases

alias v="vim"
alias vi="vim"

if which "mvim" >/dev/null; then
    alias mvim="open -a MacVim"
    alias v="mvim"
    alias vi="mvim"
    alias vim="mvim"
fi

alias vimrc="vim ~/.vimrc"
