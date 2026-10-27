#!/usr/bin/env bash
# Toggle state of bluetooth.

# Fall back to the Homebrew prefixes, since Hammerspoon runs this with a PATH that leaves them out.
blueutil_path="$(command -v blueutil)"
if [[ -z "${blueutil_path}" ]]; then
    if [[ -x "/opt/homebrew/bin/blueutil" ]]; then
        blueutil_path="/opt/homebrew/bin/blueutil"
    elif [[ -x "/usr/local/bin/blueutil" ]]; then
        blueutil_path="/usr/local/bin/blueutil"
    else
        echo "Error: blueutil not found (brew install blueutil)."
        exit 1
    fi
fi
echo "blueutil_path: ${blueutil_path}"

bluetooth_state="$("${blueutil_path}" --power)"
exit_code="${?}"
if [ "${exit_code}" -ne 0 ]; then
    echo "Error: blueutil command failed (exit code: ${exit_code})."
else
    echo "current bluetooth state: <<${bluetooth_state}>>"

    if [ "${bluetooth_state}" == "0" ]; then
        echo "bluetooth is currently OFF"
        "${blueutil_path}" --power="on"

    elif [ "${bluetooth_state}" == "1" ]; then
        echo "bluetooth is currently ON"
        "${blueutil_path}" --power="off"

    else
        echo "unknown bluetooth state: ${bluetooth_state}"
    fi
fi
