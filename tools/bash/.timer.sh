#!/usr/bin/env bash

# Benchmark / profile / timing helper: measure elapsed time of nested
# sections and print them as an indented box-drawing tree. Use `bt_push
# "label"` and `bt_pop` to bracket a section, `bt_comment` for an inline
# note. Same output style as the "Fix nvm sourcing being slow" commit.

# Example usage:
# bt_push "Doing something"
#     bt_push "Task 1"
#         sleep .2
#     bt_pop
#
#     bt_push "Task 2"
#         bt_push "Subtask A"
#             sleep .1
#         bt_pop
#
#         bt_comment "done with subtask A, doing B"
#
#         bt_push "Subtask B"
#             sleep .15
#         bt_pop
#     bt_pop
# bt_pop
#
# Example output:
#           ┌ Doing something
#           │  ┌ Task 1
#    221 ms │  └ Task 1
#           │  ┌ Task 2
#           │  │  ┌ Subtask A
#    120 ms │  │  └ Subtask A
#           │  │  done with subtask A, doing B
#           │  │  ┌ Subtask B
#    171 ms │  │  └ Subtask B
#    316 ms │  └ Task 2
#    557 ms └ Doing something

# Config.
BT_LEFTW=9 # width for left column like " 1001 ms "

# Box characters.
BT_OPEN="┌"
BT_CLOSE="└"
BT_PIPE="│"

# Internals (arrays hold a stack)
_BT_LABELS=()
_BT_STARTS=()

# gdate (coreutils) is required for %N on macOS; BSD date returns "N" literally.
_bt_now_ns() {
    gdate +%s%N
}

_bt_indent() {
    local depth=${1:-${#_BT_LABELS[@]}}
    local s=""
    local i

    for ((i = 1; i < depth; i++)); do
        s+="${BT_PIPE}  "
    done

    printf "%s" "${s}"
}

bt_push() {
    local label="$*"

    _BT_LABELS+=("${label}")
    _BT_STARTS+=("$(_bt_now_ns)")

    printf "%*s %s%s\n" \
        "${BT_LEFTW}" "" "$(_bt_indent)" "${BT_OPEN} ${label}"
}

bt_comment() {
    local msg="$1"
    local depth=${#_BT_LABELS[@]}

    if ((depth == 0)); then
        echo "bt_comment: no active block" >&2
        return 1
    fi

    local indent="$(_bt_indent "${depth}")${BT_PIPE}  "
    printf "%*s %s%s\n" \
        "${BT_LEFTW}" "" "${indent}" "${msg}"
}

bt_pop() {
    local depth=${#_BT_LABELS[@]}

    if ((depth < 1)); then
        printf '%s\n' "bt_pop: stack underflow" >&2
        return 1
    fi

    local last=$((depth - 1))
    local indent="$(_bt_indent "${depth}")"
    local end="$(_bt_now_ns)"
    local label="${_BT_LABELS[${last}]}"
    local ns_start="${_BT_STARTS[${last}]}"

    _BT_LABELS=("${_BT_LABELS[@]:0:last}")
    _BT_STARTS=("${_BT_STARTS[@]:0:last}")

    local elapsed_ns=$((end - ns_start))
    local elapsed_ms=$(((elapsed_ns + 500000) / 1000000))
    local left

    left="$(printf '%6d ms' ${elapsed_ms})"
    printf "%*s %s%s %s\n" \
        "${BT_LEFTW}" "${left}" "${indent}" "${BT_CLOSE}" "${label}"
}
