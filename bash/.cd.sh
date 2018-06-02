# Change Directory Aliases

alias ..="cd .. && l"
alias ...="cd ../.. && l"
alias ....="cd ../../.. && l"
alias .....="cd ../../../.. && l"
alias ......="cd ../../../../.. && l"
alias desktop="cd ~/Desktop"
alias dt="desktop"
alias dto="desktop && oo && x"
alias documents="cd ~/Documents"
alias doc="documents"
alias downloads="cd ~/Downloads"
alias dl="downloads"
alias dlo="downloads && oo && x"
extensions() {
    array=(
        "$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
        "$HOME/Library/Application Support/Chromium/Default/Extensions"
        "$HOME/.config/google-chrome/Default/Extensions"
        "$HOME/.config/chromium/Default/Extensions"
    )
    for path in "${array[@]}"; do
        if [ -d "${path}" ]; then
            cd "${path}"
            break
        fi
    done
}
alias exts="extensions"
alias library="cd ~/Library"
alias lib="library"
alias movies="cd ~/Movies"
alias mov="movies"
alias music="cd ~/Music"
alias mus="music"
alias projects="cd ~/Projects"
alias p="projects"
alias pictures="cd ~/Pictures"
alias pics="pictures"
alias public="cd ~/Public"
alias pub="public"
alias tmp="cd /tmp"

trash() {
    array=("$HOME/.Trash/" "$HOME/.local/share/Trash/")
    for path in "${array[@]}"; do
        if [ -d "${path}" ]; then
            cd "${path}"
            break
        fi
    done
}

www() {
    array=("/Library/WebServer/Documents/" "/var/www/")
    for path in "${array[@]}"; do
        if [ -d "${path}" ]; then
            cd "${path}"
            break
        fi
    done
}
alias ww="www"


# Add aliases that cd to the project directory and list the files.
for file in $(find ~/Projects -maxdepth 1 -mindepth 1 -type d -o -type l); do
    name=$(basename "${file}")
    alias "${name}"="cd ~/Projects/${name} && l"
    nonwwwname="${name/www\./}"
    if [[ "${nonwwwname}" != "${name}" ]]; then
        alias "${nonwwwname}"="cd ~/Projects/${name} && l"
    fi
done
