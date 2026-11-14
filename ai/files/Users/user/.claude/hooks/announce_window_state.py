#!/usr/bin/env python3
"""Drive terminal window state from Claude Code hook events.

Wired in settings.json so each event runs this script with the event name as
argv[1] and the event's JSON payload on stdin:

  SessionStart -> record the front window id, label the tab `[RUNNING]`.
  Notification -> Claude is waiting on you: `[READY]` title, Dock bounce,
                  desktop notification (a click raises the window under
                  Hammerspoon), and pull the window frontmost unless
                  the terminal app is already frontmost (you may be typing).
  PostToolUse  -> a tool finished (including one you just approved): reset to
                  `[RUNNING]`.

Each event also records the session's state word (busy, decision or ready) to
/tmp/claude-state-hook/<session_id>.state for Hammerspoon's page dots, which
watch that folder; SessionEnd deletes it along with the window record. Once the
state moves off "decision" (a prompt answered, a new turn, the turn ending),
nothing waits on the user anymore, so the Hammerspoon notification is withdrawn.

No wrapper process sits in the I/O path. The script reaches the Terminal tab by
writing OSC/bell bytes straight to the claude process's controlling tty, and
focuses the window via the id captured at launch. The objective in the title is
the session's caveman summary at /tmp/claude/<short-session-id>/objective (the
assistant writes it on the first user message, and the statusline shows the
same line), else CLAUDE_OBJECTIVE (set by `cl --obj "..."`, aliased `clo`).

The title, bell, and notification work in any terminal. The window capture and
raise pick their mechanism by the emulator claude runs in, read off TERM_PROGRAM:

  Terminal.app  -> Terminal's AppleScript dictionary. Under any other emulator
                   that `tell application "Terminal"` would launch Terminal.app
                   just to answer, popping up an empty window.
  anything else -> Hammerspoon's command-line client (`hs -c`, needs `hs.ipc`
                   loaded in its config), since emulators like Ghostty have no
                   scripting dictionary and Hammerspoon already holds the
                   accessibility grant. Hammerspoon only sees each window's
                   visible tab, so a session sitting in a background tab gets
                   its app activated rather than its tab switched to.

A missing macOS permission or client must never break Claude, so every skipped
step and osascript or Hammerspoon failure fails soft and is recorded to a log
instead. An installed Hammerspoon client that can't reach the app also posts a
desktop notification once per session, since that is a misconfiguration rather
than a machine without Hammerspoon. Tail the log while debugging "nothing happened":

  tail -f /tmp/claude-state-hook/announce_window_state.log
"""

import json
import sys
from typing import Any

from announce_window_state_models import Session
from announce_window_state_notifications import notify
from announce_window_state_records import forget_session
from announce_window_state_records import record_notification_state
from announce_window_state_records import record_session_state
from announce_window_state_records import record_stop
from announce_window_state_records import record_stop_blocked
from announce_window_state_records import record_tool_finished
from announce_window_state_records import record_turn_state
from announce_window_state_records import record_waiting_tool
from announce_window_state_scripting import log
from announce_window_state_title import objective
from announce_window_state_title import set_title
from announce_window_state_title import write_to_own_tab
from announce_window_state_windows import capture_window_id
from announce_window_state_windows import focus_window


def on_waiting(
    session: Session,
    event: dict[str, Any],
) -> None:
    """
    React to a wait-state: title, Dock bounce, notification, focus.

    :param session: Claude session waiting on the user.
    :param event: Notification hook payload.
    """
    set_title(state="READY", session=session)

    # Emit the bell straight to the terminal to bounce the Dock icon.
    write_to_own_tab("\a")

    message = event.get("message") or "Awaiting your approval"
    notify(message=message, session=session)
    focus_window(session=session)


def main() -> None:
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""

    try:
        event: dict[str, Any] = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}

    session = Session(id=event.get("session_id", ""))

    if event_name == "SessionStart":
        log(f"SessionStart: objective={objective(session=session)!r}")
        capture_window_id(session=session)
        set_title(state="RUNNING", session=session)
        # Skip a compaction's restart, which can land mid-turn while the session is still busy.
        if event.get("source") != "compact":
            record_session_state(session=session, state="ready")
    elif event_name == "Notification":
        log(
            "Notification: objective={!r} type={!r} message={!r}".format(
                objective(session=session), event.get("notification_type"), event.get("message")
            )
        )
        record_notification_state(session=session, event=event)
        on_waiting(session=session, event=event)
    elif event_name == "PermissionRequest":
        record_waiting_tool(session=session, event=event)
    elif event_name == "PreToolUse":
        # Mark a tool that waits on the user's answer (wired by matcher in settings.json).
        record_waiting_tool(session=session, event=event)
    elif event_name == "PostToolUse":
        set_title(state="RUNNING", session=session)
        record_tool_finished(session=session, event=event)
    elif event_name == "PostToolUseFailure":
        record_tool_finished(session=session, event=event)
    elif event_name == "SessionEnd":
        forget_session(session=session)
    elif event_name == "Stop":
        record_stop(session=session, event=event)
    elif event_name == "StopBlocked":
        record_stop_blocked(session=session, event=event)
    elif event_name == "UserPromptSubmit":
        record_turn_state(session=session, state="busy")


if __name__ == "__main__":
    main()
