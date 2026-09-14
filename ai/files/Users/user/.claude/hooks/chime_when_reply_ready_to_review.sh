#!/usr/bin/env bash
# Stop hook: chime when Claude finishes a turn, so a tabbed-away user comes
# back to review the reply.

set -u

afplay /System/Library/Sounds/Hero.aiff
