alias qu="_quilt"
alias quilt="_quilt"

_quilt_new() {
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

_quilt_set_alias() {
    existing_alias_to_override="${1}"
    new_alias_value="${2}"

    if type "${existing_alias_to_override}" &> /dev/null; then
        unalias "${existing_alias_to_override}"
    fi

    alias "${existing_alias_to_override}"="${new_alias_value}"
}

_quilt_series() {
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

_quilt_pop() {
    result="$(quilt pop "${@}")"
    exit_code="${?}"
    if [ "${exit_code}" -ne 0 ]; then
        echo "${result}"
        (exit "${exit_code}")
    else
        _quilt_series
    fi
}

_quilt_push() {
    result="$(quilt push "${@}")"
    exit_code="${?}"
    if [ "${exit_code}" -ne 0 ]; then
        echo "${result}"
        (exit "${exit_code}")
    else
        _quilt_series
    fi
}

_quilt_override_aliases() {
    _quilt_set_alias "n"   "_quilt_new"
    _quilt_set_alias "new" "_quilt_new"

    _quilt_set_alias "o"   "_quilt_pop"
    _quilt_set_alias "po"  "_quilt_pop"
    _quilt_set_alias "pop" "_quilt_pop"

    _quilt_set_alias "oa"     "quilt pop -a"
    _quilt_set_alias "poa"    "quilt pop -a"
    _quilt_set_alias "popa"   "quilt pop -a"
    _quilt_set_alias "popall" "quilt pop -a"

    _quilt_set_alias "pa"      "quilt patches"
    _quilt_set_alias "patches" "quilt patches"

    _quilt_set_alias "pu"   "_quilt_push"
    _quilt_set_alias "pus"  "_quilt_push"
    _quilt_set_alias "push" "_quilt_push"
    _quilt_set_alias "u"    "_quilt_push"

    _quilt_set_alias "pua"     "quilt push -a"
    _quilt_set_alias "pusha"   "quilt push -a"
    _quilt_set_alias "pushall" "quilt push -a"
    _quilt_set_alias "ua"      "quilt push -a"

    _quilt_set_alias "q" "quilt"

    _quilt_set_alias "r"       "quilt refresh"
    _quilt_set_alias "re"      "quilt refresh"
    _quilt_set_alias "ref"     "quilt refresh"
    _quilt_set_alias "refresh" "quilt refresh"

    _quilt_set_alias "se"     "_quilt_series"
    _quilt_set_alias "ser"    "_quilt_series"
    _quilt_set_alias "series" "_quilt_series"

    _quilt_set_alias "t"   "quilt top"
    _quilt_set_alias "to"  "quilt top"
    _quilt_set_alias "top" "quilt top"
}

_quilt_activate_quilt_mode() {
    export _QUILT_MODE_ON="yes"
    export _OLD_QUILT_PS1="${PS1}"

    # Use standard diff colors.
    # diff_hdr=34 - blue index line
    # diff_add=32 - green added lines
    # diff_rem=31 - red removed lines
    # diff_hunk=36 - cyan hunk header
    export QUILT_COLORS="diff_hdr=34:diff_add=32:diff_rem=31:diff_hunk=36"

    bash
    _quilt_deactivate_quilt_mode
}

_quilt_deactivate_quilt_mode() {
    if [ -n "${_OLD_QUILT_PS1}" ]; then
        export PS1="${_OLD_QUILT_PS1}"
        unset _OLD_QUILT_PS1
        unset _QUILT_MODE_ON
        unset QUILT_COLORS
    fi
}

_quilt() {
    if [ "${#}" -ne 0 ]; then
        \quilt "${@}"
    elif [ -z "${_QUILT_MODE_ON}" ]; then
        _quilt_activate_quilt_mode
    else
        \quilt "${@}"
    fi
}

if [ -n "${_QUILT_MODE_ON}" ]; then
    export PS1="(quilt) ${PS1}"
    _quilt_override_aliases
fi
