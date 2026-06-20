# Wrap `tail' with `glow' for live-rendered markdown follow output.
pretty_tail() {
    # Usage:
    #   $ tail -f progress.md
    #   $ tail_f progress.md
    #   $ tail progress.md
    #   $ tail file.log

    # Capture the last positional arg in a way that works in both bash and zsh
    # (bash's `${!#}' indirect-expansion isn't portable to zsh).
    local file=""
    local arg
    for arg in "${@}"; do
        file="${arg}"
    done

    # Plain pass-through unless the target is a markdown file on a TTY with glow available.
    if [[ ! -t 1 ]] || ! command -v "glow" &>/dev/null || [[ "${file}" != *.md ]] || [[ ! -f "${file}" ]]; then
        command tail "${@}"
        return
    fi

    # Resolve to an absolute path so watchman-wait fires regardless of caller's cwd.
    local abs
    abs="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
    local dir
    dir="$(dirname "${abs}")"
    local name
    name="$(basename "${abs}")"

    clear

    # Pin `--width' to the terminal; glow otherwise renders at ~80 and the padded
    # lines wrap on a narrower window, showing as blank gaps between rendered lines.
    glow --width="$(tput cols)" "${abs}"

    # Subshell `cd' so the caller's cwd isn't disturbed.
    # Aliases don't expand inside functions, so call the underlying function directly.
    # Escape `$(tput cols)' so it re-reads the width on each render, adapting to
    # resizes. Without this, the width expands once when pretty_tail starts and
    # goes stale after a resize.
    (cd "${dir}" && alias_watch_file --quiet "${name}" "clear; glow --width=\$(tput cols) ${abs}")
}
alias tail="pretty_tail"
# Implicit `-f' so `tail_f file.md' triggers the live render without typing the flag.
alias tail_f="pretty_tail -f"
