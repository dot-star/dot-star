"""
Resolve the session-scoped tmp dir from a raw hook session id.

Import-only (no shebang, not executable): the Python twin of
`claude_session_dir.inc.sh`, so hooks in either language build the same path.
"""

from pathlib import Path


def claude_session_dir(session_id: str) -> Path | None:
    """
    Returns /tmp/claude/<short-id> for a raw session id, or None when it is empty.

    Sanitizes to [A-Za-z0-9-], then abbreviates to 7 chars (git-short style: the
    leading hex of the uuid, dashless since the first dash sits at index 8).

    :param session_id: Raw session id from the hook payload (e.g. a uuid).
    :return: The session's tmp dir, or None when nothing survives sanitizing.
    """
    short = "".join(character for character in session_id if character.isalnum() or character == "-")[:7]

    if not short:
        return None

    return Path("/tmp/claude") / short
