#!/usr/bin/env python3
"""
Color the macOS Terminal tab per Claude Code session so sessions stay tellable apart.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> derive the session's color, save the tab's look, apply the color.
  SessionEnd   -> put the saved look back.

The color is hashed from the session id, so it holds still for a whole session
and lands somewhere else for the next one. `CLAUDE_SESSION_COLOR` picks the
mechanisms, comma-separated:

  tint    -> repaint the tab's background with a dark wash of the session's hue
  profile -> switch the tab to one of `PROFILES`, picked by the same hash
  stripe  -> write the color file only; `statusline.sh` paints the status bar

Set it to "off" for no color at all; unset behaves like `DEFAULT_MODES`. With
both "profile" and "tint" on, the profile lands first and the tint overrides its
background.

The derived color and the saved look go to /tmp/claude/<short-session-id>/color.json,
which `statusline.sh` reads for the stripe.

A crash skips SessionEnd and strands the color on the tab. Reset a stray tab by
picking any profile from Terminal > Settings, or run:

  osascript -e 'tell application "Terminal" to set current settings of selected tab of front window to settings set "Basic"'

A missing macOS permission must never break Claude, so every skipped step and
osascript failure fails soft and is recorded to a log instead. Tail it while
debugging "nothing happened":

  tail -f /tmp/claude-state-hook/session_color.log
"""

import colorsys
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

STATE_DIR = Path("/tmp/claude-state-hook")
LOG_FILE = STATE_DIR / "session_color.log"

MODES = ("profile", "stripe", "tint")
DEFAULT_MODES = "tint,stripe"

# Wash the tab background at this saturation and value: dark enough to keep
# light text readable, saturated enough to read as a color rather than as gray.
TINT_SATURATION = 0.55
TINT_VALUE = 0.15

# Paint the status bar brighter than the tab, since it covers one row rather
# than the whole window.
STRIPE_SATURATION = 0.60
STRIPE_VALUE = 0.32

# Rotate through the dark stock Terminal profiles in "profile" mode. Leave the
# light ones out; they'd flip the whole window's contrast mid-session.
PROFILES = (
    "Clear Dark",
    "Grass",
    "Homebrew",
    "Ocean",
    "Pro",
    "Red Sands",
)

# Reach the session's own tab by the tty it owns rather than by the frontmost
# window, so a session started in a background window still colors itself.
TAB_SCRIPT = """
tell application "Terminal"
    repeat with candidate_window in windows
        repeat with candidate_tab in tabs of candidate_window
            if tty of candidate_tab is "{tty}" then
                {body}
            end if
        end repeat
    end repeat
end tell
"""


def log(message):
    """Append a timestamped diagnostic line so soft failures stay visible."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with open(LOG_FILE, "a") as handle:
        handle.write("{} {}\n".format(stamp, message))


def run_osascript(script, action):
    """Run an AppleScript snippet, logging any failure with a permission hint."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        stderr = result.stderr.strip()
        log("{} failed (osascript exit {}): {}".format(action, result.returncode, stderr))
        # -1743 is macOS's "not authorized to send Apple events": Automation is off.
        if "-1743" in stderr or "Not authorized" in stderr:
            log("  fix: System Settings > Privacy & Security > Automation > Terminal > enable Terminal")

    return result


def controlling_tty():
    """Return the /dev path of the Terminal tab that owns the claude process."""
    # The hook's parent ($PPID) shares claude's controlling terminal, inherited
    # across fork and unaffected by the hook's piped stdio. ps reports it
    # abbreviated (e.g. "s003"), so re-expand to a /dev path.
    name = subprocess.check_output(
        ["ps", "-o", "tty=", "-p", str(os.getppid())],
        text=True,
    ).strip()

    if not name or name.startswith("?"):
        return None

    if not name.startswith("tty"):
        name = "tty" + name

    return "/dev/" + name


def tell_tab(tty, body, action):
    """Run an AppleScript body against the Terminal tab that owns `tty`."""
    return run_osascript(TAB_SCRIPT.format(tty=tty, body=body), action)


def read_tab(tty, expression):
    """Return an AppleScript property of the session's tab, or None if unreadable."""
    result = tell_tab(tty, "return {}".format(expression), "read {}".format(expression))

    if result.returncode != 0:
        return None

    return result.stdout.strip() or None


def state_file(session_id):
    """Return the session-scoped path holding the derived color and saved look."""
    # Abbreviate the session id git-short style, matching claude_session_dir.inc.sh.
    short = "".join(character for character in session_id if character.isalnum() or character == "-")[:7]

    if not short:
        return None

    return Path("/tmp/claude") / short / "color.json"


def selected_modes():
    """Return the mechanisms named by CLAUDE_SESSION_COLOR, as a set."""
    raw = os.environ.get("CLAUDE_SESSION_COLOR", DEFAULT_MODES)
    modes = set()

    for name in raw.split(","):
        name = name.strip().lower()
        if name in MODES:
            modes.add(name)
        elif name and name != "off":
            log("ignoring unknown CLAUDE_SESSION_COLOR mode {!r}".format(name))

    return modes


def hsv_to_rgb(hue, saturation, value, depth):
    """Convert an HSV color to an integer RGB triple scaled to `depth` (e.g. 255)."""
    channels = colorsys.hsv_to_rgb(hue / 360.0, saturation, value)

    return [round(channel * depth) for channel in channels]


def apply_profile(tty, profile):
    """Switch the session's tab to a named Terminal profile."""
    tell_tab(
        tty,
        'set current settings of candidate_tab to settings set "{}"'.format(profile),
        "set profile {}".format(profile),
    )


def apply_background(tty, rgb):
    """Repaint the session's tab background with a 16-bit-per-channel RGB triple."""
    tell_tab(
        tty,
        "set background color of candidate_tab to {{{}}}".format(", ".join(str(channel) for channel in rgb)),
        "set background {}".format(rgb),
    )


def on_session_start(event):
    """Derive this session's color, save the tab's current look, and apply it."""
    modes = selected_modes()

    if not modes:
        return

    session_id = event.get("session_id", "")
    path = state_file(session_id)

    if path is None:
        log("no session id on the payload; skipping")
        return

    # Spread sessions around the color wheel: the first digest byte picks the
    # hue, the second picks the profile, both stable for the session's life.
    digest = hashlib.sha256(session_id.encode()).digest()
    hue = digest[0] / 255.0 * 360.0

    state = {"hue": round(hue, 1), "modes": sorted(modes)}

    if "stripe" in modes:
        state["stripe"] = ";".join(str(channel) for channel in hsv_to_rgb(hue, STRIPE_SATURATION, STRIPE_VALUE, 255))

    if "profile" in modes or "tint" in modes:
        tty = controlling_tty()
        if tty is None:
            log("no controlling tty for ppid {}; tab left alone".format(os.getppid()))
        else:
            state["tty"] = tty
            state["saved_profile"] = read_tab(tty, "name of current settings of candidate_tab")
            state["saved_background"] = read_tab(tty, "background color of candidate_tab")

            # Land the profile first: it carries its own background, which the
            # tint below is meant to override when both modes are on.
            if "profile" in modes:
                apply_profile(tty, PROFILES[digest[1] % len(PROFILES)])

            if "tint" in modes:
                apply_background(tty, hsv_to_rgb(hue, TINT_SATURATION, TINT_VALUE, 65535))

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True))
    log("SessionStart: {}".format(state))


def on_session_end(event):
    """Put back the tab's look saved at SessionStart."""
    path = state_file(event.get("session_id", ""))

    if path is None or not path.exists():
        return

    state = json.loads(path.read_text())
    tty = state.get("tty")

    if tty is None:
        return

    # Restore in the same order the colors were applied, so a saved background
    # overrides whatever background the saved profile carries.
    if state.get("saved_profile"):
        apply_profile(tty, state["saved_profile"])

    if state.get("saved_background"):
        apply_background(tty, state["saved_background"].split(", "))

    log("SessionEnd ({}): restored {}".format(event.get("reason", "?"), tty))


def main():
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    if event_name == "SessionStart":
        on_session_start(event)
    elif event_name == "SessionEnd":
        on_session_end(event)


if __name__ == "__main__":
    main()
