alias re="quilt refresh"
alias ref="quilt refresh"
alias refresh="quilt refresh"
alias ser="quilt series"
alias series="quilt series"
alias to="quilt top"

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
alias new="_quilt_new"
