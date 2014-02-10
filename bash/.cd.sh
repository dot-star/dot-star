# Change Directory Aliases

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
alias desktop="cd ~/Desktop"
alias dt="desktop"
alias documents="cd ~/Documents"
alias doc="documents"
alias downloads="cd ~/Downloads"
alias dl="downloads"
alias extensions="cd ~/Library/Application\ Support/Chromium/Default/Extensions"
alias ext="extensions"
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
    array=("$HOME/.local/share/Trash/" "$HOME/.Trash/")
    for path in "${array[@]}"; do
        if [ -d "${path}" ]; then
            cd "${path}"
            break
        fi
    done
}

_www() {
    array=("/Library/WebServer/Documents/" "/var/www/")
    for path in "${array[@]}"; do
        if [ -d "${path}" ]; then
            cd "${path}"
            break
        fi
    done
}

alias ww="_www"
alias www="_www"


# Add aliases that cd to the project directory and list the files.
for file in $(find ~/Projects -maxdepth 1 -mindepth 1 -type d -o -type l); do
    name=$(basename "${file}")
    alias "${name}"="cd ~/Projects/${name} && l"
done
