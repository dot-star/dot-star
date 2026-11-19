#!/usr/bin/env python3
"""
Play a macOS system sound unless any Claude session chimed moments ago.

Sessions often finish or go idle together and each one's hook chimes, so a
shared stamp under a lock collapses near-simultaneous chimes into one.

Each chime, played or debounced, gets a timestamped line in the window-state
log beside the Notification events, so a missed ping can be traced:

  tail -f /tmp/claude-state-hook/announce_window_state.log

Usage: play_chime_unless_recent.py <sound>  (a name in /System/Library/Sounds, e.g. Glass)
"""

import fcntl
import subprocess
import sys
import time

from announce_window_state_scripting import log
from terminal_tty import STATE_DIR

# Treat chimes this close together as one alert; past it, a second chime is news.
DEBOUNCE_SECONDS = 5

STAMP_FILE = STATE_DIR / "last_chime"


def claim_chime() -> bool:
    """
    Stamp a chime now unless one was stamped within `DEBOUNCE_SECONDS`.

    Holds an exclusive lock across the read and the write, so two hooks firing
    at the same instant can't both see a stale stamp and both chime.

    :return: True when the caller should play its sound.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    now = time.time()

    with open(STAMP_FILE, "a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)

        try:
            last_chime = float(handle.read().strip())
        except ValueError:
            last_chime = 0.0

        if now - last_chime < DEBOUNCE_SECONDS:
            return False

        handle.seek(0)
        handle.truncate()
        handle.write(str(now))

    return True


def main() -> None:
    sound = sys.argv[1]

    if not claim_chime():
        log(f"chime {sound} skipped: another chime played within {DEBOUNCE_SECONDS}s")
        return

    result = subprocess.run(args=["afplay", f"/System/Library/Sounds/{sound}.aiff"], check=False)
    log(f"chime {sound} played (afplay exit {result.returncode})")


if __name__ == "__main__":
    main()
