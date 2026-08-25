#!/usr/bin/env bash

# Reap stale Claude background workers.
#
# Scans running `claude bg-pty-host` processes and kills any launched against a
# version binary that no longer exists under ~/.local/share/claude/versions/.
# Such a worker can never be respawned or upgraded, yet the daemon still counts
# it as live and waits for it to settle, so it blocks the daemon's idle-exit
# forever. Workers on an installed version are left alone; the daemon upgrades
# those on its own once they go idle.

set -euo pipefail

printf '🟡 Reaping stale Claude workers...'

# Print the version-binary path a worker was launched against, i.e. the token
# following the `--` separator in its command line.
version_path_of() {
    local pid="${1}"
    ps -o command= -p "${pid}" 2>/dev/null |
        awk '{ for (i = 1; i < NF; i++) { if ($i == "--") { print $(i + 1); exit } } }'
}

# Terminate a process, escalating to SIGKILL if it ignores the polite signal.
terminate() {
    local pid="${1}"
    kill "${pid}" 2>/dev/null || true
    sleep 0.2
    if kill -0 "${pid}" 2>/dev/null; then
        kill -KILL "${pid}" 2>/dev/null || true
    fi
}

reaped=()
live=0
while IFS= read -r host_pid; do
    version_path="$(version_path_of "${host_pid}")"

    if [[ -z "${version_path}" || -e "${version_path}" ]]; then
        live=$((live + 1))
        continue
    fi

    # Take the spare children down first so launchd doesn't adopt them.
    while IFS= read -r child_pid; do
        terminate "${child_pid}"
    done < <(pgrep -P "${host_pid}" || true)

    terminate "${host_pid}"
    reaped+=("${host_pid} $(basename "${version_path}")")
done < <(pgrep -f 'claude bg-pty-host' || true)

printf '\r\033[K\033[90m⚪️ Reaping stale Claude workers... done (%d reaped, %d live)\033[0m\n' "${#reaped[@]}" "${live}"

if [[ "${#reaped[@]}" -gt 0 ]]; then
    for entry in "${reaped[@]}"; do
        printf '\033[90m   killed pid %s (version %s)\033[0m\n' "${entry%% *}" "${entry#* }"
    done
fi
