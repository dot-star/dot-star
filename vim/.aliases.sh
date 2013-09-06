# Vim aliases

if which "mvim" >/dev/null; then
    alias mvim="open -a MacVim"
    alias v="mvim"
    alias vi="mvim"
    alias vim="mvim"
else
    alias v="vim"
    alias vi="vim"
fi

alias vimrc="vim ~/.vimrc"
