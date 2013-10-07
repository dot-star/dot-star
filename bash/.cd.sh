# Change Directory Aliases

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
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
alias www="cd /Library/WebServer/Documents"
alias ww="www"

# Add aliases that cd to the project directory and list the files.
for file in $(find ~/Projects -maxdepth 1 -mindepth 1 -type d); do
    name=$(basename "${file}")
    alias "${name}"="cd ~/Projects/${name} && l"
done
