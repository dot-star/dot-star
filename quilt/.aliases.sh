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

_quilt_override_aliases() {
    _quilt_set_alias "n"   "_quilt_new"
    _quilt_set_alias "new" "_quilt_new"

    _quilt_set_alias "po"  "quilt pop"
    _quilt_set_alias "pop" "quilt pop"

    _quilt_set_alias "pu"   "quilt push"
    _quilt_set_alias "push" "quilt push"

    _quilt_set_alias "q" "quilt"

    _quilt_set_alias "r"       "quilt refresh"
    _quilt_set_alias "re"      "quilt refresh"
    _quilt_set_alias "ref"     "quilt refresh"
    _quilt_set_alias "refresh" "quilt refresh"

    _quilt_set_alias "se"     "quilt series"
    _quilt_set_alias "ser"    "quilt series"
    _quilt_set_alias "series" "quilt series"

    _quilt_set_alias "t"   "quilt top"
    _quilt_set_alias "to"  "quilt top"
    _quilt_set_alias "top" "quilt top"
}

_quilt_activate_quilt_mode() {
    export _QUILT_MODE_ON="yes"
    export _OLD_QUILT_PS1="${PS1}"
    export PS1="(quilt) ${PS1}"

    bash
    _quilt_deactivate_quilt_mode
}

_quilt_deactivate_quilt_mode() {
    if [ -n "${_OLD_QUILT_PS1}" ]; then
        export PS1="${_OLD_QUILT_PS1}"
        unset _OLD_QUILT_PS1
        unset _QUILT_MODE_ON
    fi
}

_quilt() {
    if [ -z "${_QUILT_MODE_ON}" ]; then
        _quilt_activate_quilt_mode
    else
        \quilt "${@}"
    fi
}

if [ -n "${_QUILT_MODE_ON}" ]; then
    _quilt_override_aliases
fi
