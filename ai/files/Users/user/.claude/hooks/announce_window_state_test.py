#!/usr/bin/env python3
"""
Tests for announce_window_state: which Notification events get announced.

Stands in for the announcement itself (`on_waiting`) and the state records it
writes, so the suite never bounces the Dock or posts a notification.
"""

import io
import json
import sys
import unittest
from typing import Any
from unittest import mock

import announce_window_state

SESSION_ID = "12345678-90ab-cdef-1234-567890abcdef"


class NotificationTest(unittest.TestCase):
    """Test the Notification branch of `main`."""

    def setUp(self) -> None:
        for patcher in [
            mock.patch.object(announce_window_state, "objective", return_value=""),
            mock.patch.object(announce_window_state, "log"),
            mock.patch.object(announce_window_state, "record_notification_state"),
        ]:
            patcher.start()
            self.addCleanup(patcher.stop)

        on_waiting = mock.patch.object(announce_window_state, "on_waiting")
        self.on_waiting = on_waiting.start()
        self.addCleanup(on_waiting.stop)

    def notify(self, event: dict[str, Any]) -> None:
        """
        Runs the hook on a Notification event.

        :param event: Notification payload minus the session id, as loose as the JSON Claude Code sends (e.g. `{"notification_type": "idle_prompt"}`).
        """
        payload = json.dumps({"session_id": SESSION_ID, **event})
        with (
            mock.patch.object(sys, "argv", ["announce_window_state.py", "Notification"]),
            mock.patch.object(sys, "stdin", io.StringIO(payload)),
        ):
            announce_window_state.main()

    def test_announces_a_permission_prompt(self) -> None:
        """Ensure main announces a notification when it asks the user for a decision."""
        self.notify({"notification_type": "permission_prompt"})
        self.on_waiting.assert_called_once()

    def test_stays_silent_on_auth_success(self) -> None:
        """Ensure main skips the announcement when the notification leaves the user nothing to do."""
        self.notify({"notification_type": "auth_success"})
        self.on_waiting.assert_not_called()

    def test_stays_silent_without_a_notification_type(self) -> None:
        """Ensure main skips the announcement when the notification carries no type."""
        self.notify({"message": "Something happened"})
        self.on_waiting.assert_not_called()


if __name__ == "__main__":
    unittest.main()
