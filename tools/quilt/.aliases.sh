alias qu="alias_quilt"
alias quilt="alias_quilt"

quilt_new() {
    # Usage:
    #   $ new changes.diff
    #   quilt new changes.diff
    #
    #   $ new changes
    #   quilt new changes.diff
    #
    #   $ new my changes
    #   quilt new my-changes.diff

    file_name="${@}"
    file_name="$(echo "${file_name}" | slugify)"

    if [[ "${file_name}" != *".diff" ]]; then
        file_name="${file_name}.diff"
    fi

    set -x
    quilt new "${file_name}"
    set +x
}

quilt_set_alias() {
    existing_alias_to_override="${1}"
    new_alias_value="${2}"

    if type "${existing_alias_to_override}" &>/dev/null; then
        unalias "${existing_alias_to_override}"
    fi

    alias "${existing_alias_to_override}"="${new_alias_value}"
}

quilt_series() {
    # Improve `quilt series' output.
    #
    # Before:
    #   $ quilt series
    #   patches/patch1.diff
    #   patches/patch2.diff
    #   patches/patch3.diff
    #   patches/patch4.diff
    #   patches/patch5.diff
    #   patches/patch6.diff
    #   patches/patch7.diff
    #
    #   $ quilt series -v
    #   + patches/patch1.diff
    #   + patches/patch2.diff
    #   + patches/patch3.diff
    #   = patches/patch4.diff
    #     patches/patch5.diff
    #     patches/patch6.diff
    #     patches/patch7.diff
    #
    # After:
    #   $ quilt series
    #     patches/patch1.diff
    #     patches/patch2.diff
    #     patches/patch3.diff
    #   → patches/patch4.diff
    #     patches/patch5.diff
    #     patches/patch6.diff
    #     patches/patch7.diff
    #
    quilt series --color="always" -v |
        perl -pe "s/^(.*)\+ /  \1/" |
        perl -pe "s/^(.*)= /\1→ /"
}

quilt_pop() {
    result="$(quilt pop "${@}")"
    exit_code="${?}"
    if [ "${exit_code}" -ne 0 ]; then
        echo "${result}"
        (exit "${exit_code}")
    else
        quilt_series
    fi
}

quilt_push() {
    result="$(quilt push --color="always" "${@}")"
    exit_code="${?}"
    if [ "${exit_code}" -ne 0 ]; then
        echo "${result}"
        (exit "${exit_code}")
    else
        quilt_series
    fi
}

quilt_override_aliases() {
    quilt_set_alias "e" "quilt edit"
    quilt_set_alias "edit" "quilt edit"

    quilt_set_alias "files" "quilt files"

    quilt_set_alias "n" "quilt_new"
    quilt_set_alias "new" "quilt_new"

    quilt_set_alias "o" "quilt_pop"
    quilt_set_alias "po" "quilt_pop"
    quilt_set_alias "pop" "quilt_pop"

    quilt_set_alias "oa" "quilt pop -a"
    quilt_set_alias "poa" "quilt pop -a"
    quilt_set_alias "popa" "quilt pop -a"
    quilt_set_alias "popall" "quilt pop -a"

    quilt_set_alias "pa" "quilt patches"
    quilt_set_alias "patches" "quilt patches"

    quilt_set_alias "pu" "quilt_push"
    quilt_set_alias "pus" "quilt_push"
    quilt_set_alias "push" "quilt_push"
    quilt_set_alias "u" "quilt_push"

    quilt_set_alias "pua" "quilt push -a"
    quilt_set_alias "pusha" "quilt push -a"
    quilt_set_alias "pushall" "quilt push -a"
    quilt_set_alias "ua" "quilt push -a"

    quilt_set_alias "q" "quilt"

    quilt_set_alias "r" "quilt refresh"
    quilt_set_alias "re" "quilt refresh"
    quilt_set_alias "ref" "quilt refresh"
    quilt_set_alias "refresh" "quilt refresh"

    quilt_set_alias "se" "quilt_series"
    quilt_set_alias "ser" "quilt_series"
    quilt_set_alias "series" "quilt_series"

    quilt_set_alias "t" "quilt top"
    quilt_set_alias "to" "quilt top"
    quilt_set_alias "top" "quilt top"
}

quilt_activate_quilt_mode() {
    export _QUILT_MODE_ON="yes"
    export _OLD_QUILT_PS1="${PS1}"

    # Use standard diff colors.
    # diff_hdr=34 - blue index line
    # diff_add=32 - green added lines
    # diff_rem=31 - red removed lines
    # diff_hunk=36 - cyan hunk header
    export QUILT_COLORS="diff_hdr=34:diff_add=32:diff_rem=31:diff_hunk=36"

    bash
    quilt_deactivate_quilt_mode
}

quilt_deactivate_quilt_mode() {
    if [ -n "${_OLD_QUILT_PS1}" ]; then
        export PS1="${_OLD_QUILT_PS1}"
        unset _OLD_QUILT_PS1
        unset _QUILT_MODE_ON
        unset QUILT_COLORS
    fi
}

alias_quilt() {
    if [ "${#}" -ne 0 ]; then
        \quilt "${@}"
    elif [ -z "${_QUILT_MODE_ON}" ]; then
        quilt_activate_quilt_mode
    else
        \quilt "${@}"
    fi
}

if [ -n "${_QUILT_MODE_ON}" ]; then
    export PS1="(quilt) ${PS1}"
    quilt_override_aliases
fi
