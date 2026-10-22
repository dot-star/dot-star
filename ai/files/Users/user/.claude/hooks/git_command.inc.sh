# Split a Bash tool command line into the commands it runs and pick out the git
# subcommands among them. Source this; don't execute it. Share the parsing so
# every hook that reacts to a git subcommand reads the line the same way.

# Hold the commands the last `split_commands` call produced.
segments=()

# Push a segment onto `segments` with its edge spaces stripped, dropping the
# empty one a `&&` pair or a trailing separator leaves.
add_segment() {
    local text="${1}"

    while [[ "${text}" == " "* ]]; do
        text="${text# }"
    done

    while [[ "${text}" == *" " ]]; do
        text="${text% }"
    done

    if [[ -n "${text}" ]]; then
        segments+=("${text}")
    fi
}

# Split a command line into `segments`, one per command it runs, treating a
# separator inside quotes as argument text. Leave every other metacharacter
# in place for the per-command checks to reject.
split_commands() {
    local text="${1}"
    local quote=""
    local current=""
    local index=0
    local char

    segments=()
    while [[ "${index}" -lt "${#text}" ]]; do
        char="${text:index:1}"
        index=$((index + 1))

        if [[ -n "${quote}" ]]; then
            if [[ "${char}" == "${quote}" ]]; then
                quote=""
            fi
            current+="${char}"
            continue
        fi

        case "${char}" in
        '"' | "'")
            quote="${char}"
            current+="${char}"
            ;;
        ';' | '&' | '|' | $'\n')
            add_segment "${current}"
            current=""
            ;;
        *)
            current+="${char}"
            ;;
        esac
    done

    add_segment "${current}"
}

# Print the words after the subcommand when one segment runs that git
# subcommand, and fail otherwise. Step over git's global options
# (`git -C <path> commit`), each listed one spending the next word as its value.
git_subcommand_args() {
    local segment="${1}"
    local subcommand="${2}"
    local value="(\"[^\"]*\"|'[^']*'|[^[:space:]]+)"
    local valued_option="(-C|-c|--config-env|--git-dir|--namespace|--work-tree)"
    local global_option="[[:space:]]+(${valued_option}[[:space:]]+${value}|-[^[:space:]]*)"
    local git_subcommand="^git(${global_option})*[[:space:]]+${subcommand}([[:space:]]|$)"

    if [[ ! "${segment}" =~ ${git_subcommand} ]]; then
        return 1
    fi

    printf '%s' "${segment:${#BASH_REMATCH[0]}}"
}
