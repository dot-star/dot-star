export DISABLE_TELEMETRY=1

alias cl="claude"
alias clr="claude --resume"
alias clcm="claude --print --output-format=json 'give me a one liner commit message for the staged changes' | \jq -r .result"
