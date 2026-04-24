export DISABLE_TELEMETRY=1

alias cl="claude"
alias clr="claude --resume"

claude_git_commit() {
    local prompt options selected
    prompt="$(
        cat <<'EOF'
Write 5 alternative single-line git commit messages for the currently staged changes.

Output:
- One message per line
- No numbering, bullets, quotes, preamble, or blank lines

Each message:
- Imperative mood, capitalized first word (Add/Fix/Update/Move/Allow/Enable/Replace/Rename/Clean up)
- No trailing period
- No conventional-commits prefix (no feat:/fix:/chore:)
- Under 70 characters
EOF
    )"
    options="$(
        claude --print --output-format=json "${prompt}" |
            \jq -r .result
    )"
    if [[ -z "${options}" ]]; then
        return 1
    fi

    selected="$(
        echo "${options}" |
            fzf --prompt='Select commit message: ' --height=40%
    )"
    if [[ -z "${selected}" ]]; then
        return 1
    fi

    git commit -m "${selected}"
}
alias clcm="claude_git_commit"
