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

# Connect headphones whose name contains this after power-on. Match by name to keep device addresses out of the repo.
headphones_name="AirPods Pro"

bluetooth_state="$("${blueutil_path}" --power)"
exit_code="${?}"
if [ "${exit_code}" -ne 0 ]; then
    echo "Error: blueutil command failed (exit code: ${exit_code})."
else
    echo "current bluetooth state: <<${bluetooth_state}>>"

    if [ "${bluetooth_state}" == "0" ]; then
        echo "bluetooth is currently OFF"
        "${blueutil_path}" --power="on"

        echo "fetching paired device addresses for headphones containing: ${headphones_name}"
        headphones_addresses="$(
            "${blueutil_path}" \
                --paired \
                --format json |
                jq \
                    --raw-output \
                    --arg name "${headphones_name}" \
                    '.[] | select(.name | contains($name)) | .address'
        )"
        if [[ -z "${headphones_addresses}" ]]; then
            echo "no paired device name contains: ${headphones_name}"
        else
            echo "found paired device addresses"

            # Retry the connect, since the radio needs a moment after power-on.
            # Try every match each round, since only the pair in use is in range.
            for attempt in 1 2 3 4 5; do
                for headphones_address in ${headphones_addresses}; do
                    if "${blueutil_path}" --connect "${headphones_address}"; then
                        echo "connected to ${headphones_address} on attempt ${attempt}"
                        break 2
                    fi
                done

                echo "connect attempt ${attempt} failed, retrying in 1 second..."
                sleep 1
            done
        fi

    elif [ "${bluetooth_state}" == "1" ]; then
        echo "bluetooth is currently ON"
        "${blueutil_path}" --power="off"

    else
        echo "unknown bluetooth state: ${bluetooth_state}"
    fi
fi
