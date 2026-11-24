#!/usr/bin/env python3
"""
UserPromptSubmit hook: block a prompt carrying a YubiKey one-time password.

A brushed YubiKey types its OTP and presses Return, so the code submits as a
prompt (or lands at the end of a half-typed one) and costs a turn. Blocking
hands the prompt back to the input field, so the user deletes the code and
resends whatever they meant to type.

A Yubico OTP is a public id of 0 to 16 bytes plus a 16-byte encrypted token,
each byte typed as two modhex letters. Modhex (`cbdefghijklnrtuv`) has no
vowel but `e`, `i` and `u`, so a run of 32 or more of those letters never
occurs in prose, a path or a hex hash.

Usage:
    Listed in `blocking_hooks` in mark_turn_busy_unless_prompt_blocked.sh,
    which runs it on every UserPromptSubmit.
"""

import json
import re
import sys

# Match a standalone modhex run as long as an OTP: 32 letters of token plus up
# to 32 of public id. Ignore case so a key typing under Caps Lock still matches.
OTP_PATTERN = re.compile(
    r"(?<![0-9a-z])[cbdefghijklnrtuv]{32,64}(?![0-9a-z])",
    flags=re.IGNORECASE,
)

BLOCK_REASON = (
    "Blocked a YubiKey one-time password (an accidental key tap?)."
    " The prompt never reached Claude; delete the code and resend."
)


def contains_otp(prompt: str) -> bool:
    """
    Returns whether a prompt carries a YubiKey one-time password.

    :param prompt: Prompt text as the user submitted it.
    :return: True when any standalone modhex run is OTP length.
    """
    return OTP_PATTERN.search(prompt) is not None


def main() -> None:
    """Read the hook payload on stdin and print a block decision for a YubiKey OTP."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # Let the prompt through when stdin is not valid JSON.
        return

    if not isinstance(payload, dict):
        return

    prompt = payload.get("prompt")
    if not isinstance(prompt, str):
        return
    elif not contains_otp(prompt=prompt):
        # Print nothing so the prompt goes through.
        return

    # Use `decision: "block"` over `continue: false`, which would keep the
    # prompt in the transcript instead of returning it to the input field.
    json.dump(
        {
            "decision": "block",
            "reason": BLOCK_REASON,
        },
        sys.stdout,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
