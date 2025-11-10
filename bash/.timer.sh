#!/usr/bin/env zsh

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
BT_LEFTW=9  # width for left column like " 1001 ms "

# Box characters.
BT_OPEN="┌"
BT_CLOSE="└"
BT_PIPE="│"

# Internals (arrays hold a stack)
declare -a _BT_LABELS=()
declare -a _BT_STARTS=()

_bt_now_ns() {
    date +%s%N
}

_bt_indent() {
    local depth=${1:-${#_BT_LABELS}}
    local s=""
    local i

    for ((i=1;i<depth;i++)); do
        s+="${BT_PIPE}  "
    done

    printf "%s" "$s"
}

bt_push() {
    local label="$*"

    _BT_LABELS+="$label"
    _BT_STARTS+="$(_bt_now_ns)"

    printf "%*s %s%s\n" \
        "$BT_LEFTW" "" "$(_bt_indent)" "${BT_OPEN} ${label}"
}

bt_comment() {
    local msg="$1"
    local depth=${#_BT_LABELS}

    if (( depth == 0 )); then
        echo "bt_comment: no active block" >&2
        return 1
    fi

    local indent="$(_bt_indent "$depth")${BT_PIPE}  "
    printf "%*s %s%s\n" \
        "$BT_LEFTW" "" "$indent" "$msg"
}

bt_pop() {
    local end idx depth label ns_start elapsed_ns elapsed_ms left indent

    depth=${#_BT_LABELS}
    if (( depth < 1 )); then
        print -ru2 -- "bt_pop: stack underflow"
        return 1
    fi

    idx=$depth
    indent="$(_bt_indent $depth)"
    end="$(_bt_now_ns)"
    label="${_BT_LABELS[$idx]}"
    ns_start="${_BT_STARTS[$idx]}"

    _BT_LABELS=("${(@)_BT_LABELS[1,$((idx-1))]}")
    _BT_STARTS=("${(@)_BT_STARTS[1,$((idx-1))]}")

    elapsed_ns=$(( end - ns_start ))
    elapsed_ms=$(( (elapsed_ns + 500000) / 1000000 ))

    left="$(printf '%6d ms' $elapsed_ms)"
    printf "%*s %s%s %s\n" \
        $BT_LEFTW "$left" "$indent" "$BT_CLOSE" "$label"
}
