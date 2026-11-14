"""
Reach macOS apps for `announce_window_state.py`: osascript, Hammerspoon's `hs -c`, and the log both fail soft into.

Import-only (no shebang, not executable): the `announce_window_state_*` modules
import it from the hooks directory, which Python puts on `sys.path` when it runs
a script there.
"""

import subprocess

from announce_window_state_models import Session
from terminal_tty import STATE_DIR
from terminal_tty import append_log

LOG_FILE = STATE_DIR / "announce_window_state.log"

# Reach Hammerspoon through the client shipped inside its bundle rather than a
# PATH lookup, since hooks run with claude's environment, not the login shell's.
HAMMERSPOON_CLI = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"


def log(message: str) -> None:
    """Append a timestamped diagnostic line so soft failures stay visible."""
    append_log(LOG_FILE, message)


def applescript_quote(text: str) -> str:
    """Escape a string for safe interpolation into an AppleScript literal."""
    return text.replace("\\", "\\\\").replace('"', '\\"')


def run_osascript(script: str, action: str) -> subprocess.CompletedProcess[str]:
    """Run an AppleScript snippet, logging any failure with a permission hint."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        stderr = result.stderr.strip()
        log(f"{action} failed (osascript exit {result.returncode}): {stderr}")
        # -1743 is macOS's "not authorized to send Apple events": Automation is off.
        if "-1743" in stderr or "Not authorized" in stderr:
            log("  fix: System Settings > Privacy & Security > Automation > Terminal > enable Terminal")

    return result


def alert_hammerspoon_unreachable(session: Session) -> None:
    """
    Post a desktop notification that Hammerspoon's client can't reach the app, once per session.

    :param session: Claude session the once-only marker is filed under.
    """
    marker = session.hammerspoon_alerted_file

    if marker.exists():
        return

    marker.touch()
    run_osascript(
        'display notification "Window capture and raise are off. Check Hammerspoon is running with require(\'hs.ipc\') in its init.lua." with title "Hammerspoon unreachable"',
        "post Hammerspoon alert",
    )


def run_hammerspoon(
    lua: str,
    action: str,
    session: Session,
) -> str | None:
    """
    Run a Lua snippet inside Hammerspoon, returning its printed result or None on failure.

    :param lua: Lua source for `hs -c`; its `return` value comes back as text.
    :param action: Short label for the log line (e.g. "capture window id").
    :param session: Claude session whose once-only failure alert this may fire.
    :return: The snippet's return value, stripped, or None when the client is
        missing or the snippet errored.
    """
    try:
        result = subprocess.run(
            [HAMMERSPOON_CLI, "-c", lua],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as error:
        log(f"{action} failed (no Hammerspoon client at {HAMMERSPOON_CLI}): {error}")
        return None

    if result.returncode != 0:
        log(f"{action} failed (hs exit {result.returncode}): {result.stderr.strip()}")
        log("  fix: Hammerspoon must be running with `require('hs.ipc')` in its init.lua")
        # Alert only here, not on a missing client above: an installed client that can't connect is a misconfiguration.
        alert_hammerspoon_unreachable(session=session)
        return None

    return result.stdout.strip()


def lua_quote(text: str) -> str:
    """
    Returns a Lua long-bracket string literal holding the text verbatim.

    :param text: Text to embed (e.g. a notification body).
    :return: The text wrapped in `[[` and `]]`, padded with enough `=` that
        no `]]` inside the text closes it early.
    """
    level = 0

    while f"]{'=' * level}]" in text:
        level += 1

    equals = "=" * level
    return f"[{equals}[{text}]{equals}]"
