export DISABLE_TELEMETRY=1

claude_run() {
    # Run claude, optionally resuming a session.
    # Usage:
    #   claude_run                 # start a new session
    #   claude_run <uuid>          # resume session <uuid>
    #   claude_run --resume <uuid> # resume session <uuid> (explicit flag)

    local uuid_pattern='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    # Explicit `--resume <uuid>` form: pass straight through.
    if [[ "$1" == "--resume" ]]; then
        claude "$@"
    # Bare uuid as first arg: treat it as the session id to resume.
    elif [[ "$1" =~ ${uuid_pattern} ]]; then
        claude --resume "$@"
    # No args (or anything that isn't a uuid): start a fresh session.
    else
        claude "$@"
    fi

    ~/.dot-star/ai/claude/prune.sh
}
alias cl="claude_run"

alias .cl="cd ~/.claude/ && l"

alias clr="claude_run --resume"

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
            fzf --no-sort --reverse --prompt='Select commit message: ' --height=40%
    )"
    if [[ -z "${selected}" ]]; then
        return 1
    fi

    git commit -m "${selected}"
}

# Adding various. Let's see which one sticks.
alias aic="claude_git_commit"
alias cgc="claude_git_commit"
alias clc="claude_git_commit"
alias clcm="claude_git_commit"
alias cma="claude_git_commit"
alias cmc="claude_git_commit"

alias clp="~/.dot-star/ai/claude/prune.sh"
alias prune="~/.dot-star/ai/claude/prune.sh"
