#!/usr/bin/env python3
"""
Picks one subject per commit a Claude commit menu queued, in side-by-side panes.

Each pane shows one queued commit: its subject drafts on top, its diff below.
The menu writes `series/<N>` (mode, worktree, paths) and `series/<N>.subjects`
(a label line, then one `cK <subject>` draft per line) under
`/tmp/claude/<session_id>/`. Return sends the reply (e.g. `c1 c5 c8`).

`--new-window` is the form a Claude session runs: it opens the picker in a new
Ghostty window and returns at once. Return there refocuses the session's
terminal and types the reply into it, so the session reads the picks as the
user's answer; `q` refocuses it without typing. Run in a terminal by hand, the
picker copies the reply to the clipboard instead.

    Usage:
        pick_series_subjects.py [--new-window] [<series_dir>]

    Example:
        pick_series_subjects.py --new-window /tmp/claude/1234567/series
"""

import argparse
import curses
import os
import shlex
import subprocess
import sys
from pathlib import Path

SERIES_GLOB = "/tmp/claude/*/series"
KEY_HELP = "Left/Right: commit  Up/Down: subject  PgUp/PgDn: scroll  Return: send  q: quit"

# Open the picker in a new Ghostty window and bring it to the front.
OPEN_WINDOW_SCRIPT = """
on run argv
    tell application "Ghostty"
        set surfaceConfiguration to new surface configuration
        set command of surfaceConfiguration to item 1 of argv
        set wait after command of surfaceConfiguration to false
        new window with configuration surfaceConfiguration
        activate
    end tell
end run
"""

# Focus the terminal on the given tty and type the reply into it, then press Return.
SEND_REPLY_SCRIPT = """
on run argv
    set targetTty to item 1 of argv
    set reply to item 2 of argv
    tell application "Ghostty"
        repeat with candidate in terminals
            if tty of candidate is targetTty then
                focus candidate
                if reply is not "" then
                    input text reply to candidate
                    send key "enter" action press to candidate
                    send key "enter" action release to candidate
                end if
                return "sent"
            end if
        end repeat
    end tell
    return "missing"
end run
"""


class QueuedCommit:
    """Holds one queued commit's subject drafts and diff."""

    def __init__(
        self,
        number: int,
        label: str,
        drafts: list[tuple[str, str]],
        diff_lines: list[str],
    ) -> None:
        """
        Stores a queued commit.

        :param number: Position in the series (e.g. 2 for commit 2 of 3).
        :param label: What the commit holds (e.g. "Audit scans once").
        :param drafts: Accept token and subject per draft
            (e.g. `("c4", "Chore: Scan for leaking raises once")`).
        :param diff_lines: Lines of the commit's diff, uncolored.
        """
        self.number = number
        self.label = label
        self.drafts = drafts
        self.diff_lines = diff_lines
        self.picked = 0
        self.scroll = 0

    @classmethod
    def load(
        cls,
        series_dir: Path,
        number: int,
    ) -> "QueuedCommit":
        """
        Reads commit N's series file and subjects file, then runs its diff.

        :param series_dir: Directory holding the series files.
        :param number: Position of the commit to load.
        :return: The commit, with its diff taken from the worktree as it is now.
        """
        series_lines = (series_dir / str(number)).read_text().splitlines()
        mode = series_lines[0]
        worktree = series_lines[1]
        paths = series_lines[2:]

        subject_lines = (series_dir / f"{number}.subjects").read_text().splitlines()
        label = subject_lines[0]
        drafts: list[tuple[str, str]] = []
        for line in subject_lines[1:]:
            token, _, subject = line.partition(" ")
            drafts.append((token, subject))

        diff_command = ["git", "-C", worktree, "diff", "--no-color"]
        if mode == "staged":
            diff_command.append("--cached")
        diff_command.append("--")
        diff_command.extend(paths)
        diff = subprocess.run(
            diff_command,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        diff_lines = [line.expandtabs(4) for line in diff.splitlines()]
        return cls(
            number=number,
            label=label,
            drafts=drafts,
            diff_lines=diff_lines,
        )

    def picked_token(self) -> str:
        """Returns the accept token of the draft currently picked."""
        return self.drafts[self.picked][0]


class SeriesPicker:
    """Draws the panes and handles keys until the user copies or quits."""

    def __init__(
        self,
        commits: list[QueuedCommit],
    ) -> None:
        """
        Starts the picker on the first commit.

        :param commits: Queued commits in series order, one pane each.
        """
        self.commits = commits
        self.focused = 0

    def reply(self) -> str:
        """Returns the reply naming every pane's pick (e.g. `c1 c5 c8`)."""
        return " ".join(commit.picked_token() for commit in self.commits)

    def run(
        self,
        screen: "curses.window",
    ) -> str | None:
        """
        Runs the key loop.

        :param screen: Full-terminal window curses hands the wrapper.
        :return: The reply on Return, None on quit.
        """
        curses.curs_set(0)
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_GREEN, -1)
        curses.init_pair(2, curses.COLOR_RED, -1)
        curses.init_pair(3, curses.COLOR_CYAN, -1)
        curses.init_pair(4, curses.COLOR_YELLOW, -1)

        while True:
            self.draw(screen)
            key = screen.getch()
            commit = self.commits[self.focused]
            diff_page = max(1, screen.getmaxyx()[0] // 2)
            if key == ord("q"):
                return None
            elif key in (curses.KEY_ENTER, 10, 13):
                return self.reply()
            elif key in (curses.KEY_LEFT, ord("h")):
                self.focused = max(0, self.focused - 1)
            elif key in (curses.KEY_RIGHT, ord("l"), ord("\t")):
                self.focused = min(len(self.commits) - 1, self.focused + 1)
            elif key in (curses.KEY_UP, ord("k")):
                commit.picked = max(0, commit.picked - 1)
            elif key in (curses.KEY_DOWN, ord("j")):
                commit.picked = min(len(commit.drafts) - 1, commit.picked + 1)
            elif key in (curses.KEY_PPAGE, ord("b")):
                commit.scroll = max(0, commit.scroll - diff_page)
            elif key in (curses.KEY_NPAGE, ord(" ")):
                last_start = max(0, len(commit.diff_lines) - diff_page)
                commit.scroll = min(last_start, commit.scroll + diff_page)

    def draw(
        self,
        screen: "curses.window",
    ) -> None:
        """
        Redraws every pane and the footer from the current state.

        :param screen: Full-terminal window curses hands the wrapper.
        """
        screen.erase()
        height, width = screen.getmaxyx()
        pane_width = width // len(self.commits)
        for index, commit in enumerate(self.commits):
            self.draw_pane(
                screen=screen,
                commit=commit,
                left=index * pane_width,
                width=pane_width - 1,
                height=height - 1,
                is_focused=index == self.focused,
            )
            if index > 0:
                screen.vline(0, index * pane_width - 1, curses.ACS_VLINE, height - 1)

        footer = f" {KEY_HELP}   reply: {self.reply()}"
        screen.addnstr(height - 1, 0, footer, width - 1, curses.A_REVERSE)
        screen.refresh()

    def draw_pane(
        self,
        screen: "curses.window",
        commit: QueuedCommit,
        left: int,
        width: int,
        height: int,
        is_focused: bool,
    ) -> None:
        """
        Draws one commit's title, drafts and visible diff lines.

        :param screen: Full-terminal window curses hands the wrapper.
        :param commit: Commit the pane shows.
        :param left: Column the pane starts at.
        :param width: Columns the pane may fill, its border excluded.
        :param height: Rows the pane may fill, the footer excluded.
        :param is_focused: True when the arrow keys act on this pane.
        """
        title = f" {commit.number} of {len(self.commits)}: {commit.label}"
        title_attribute = curses.A_REVERSE if is_focused else curses.A_BOLD
        screen.addnstr(0, left, title.ljust(width), width, title_attribute)

        row = 1
        for index, (token, subject) in enumerate(commit.drafts):
            marker = "●" if index == commit.picked else "○"
            attribute = curses.A_NORMAL
            if index == commit.picked:
                attribute = curses.A_BOLD
            screen.addnstr(row, left, f" {marker} {token} {subject}", width, attribute)
            row += 1

        screen.hline(row, left, curses.ACS_HLINE, width)
        row += 1

        visible = commit.diff_lines[commit.scroll : commit.scroll + height - row]
        for line in visible:
            screen.addnstr(row, left, line, width, self.diff_attribute(line))
            row += 1

    @staticmethod
    def diff_attribute(line: str) -> int:
        """
        Returns the color a diff line renders in.

        :param line: One line of `git diff` output (e.g. "+import json").
        :return: Curses attribute for the line.
        """
        if line.startswith("diff --git"):
            return curses.color_pair(4) | curses.A_BOLD
        elif line.startswith(("+++ ", "--- ")):
            return curses.color_pair(4)
        elif line.startswith("@@"):
            return curses.color_pair(3)
        elif line.startswith("+"):
            return curses.color_pair(1)
        elif line.startswith("-"):
            return curses.color_pair(2)
        return curses.A_NORMAL


def find_newest_series_dir() -> Path | None:
    """Returns the series directory whose files changed most recently."""
    newest_dir = None
    newest_time = 0.0
    for series_dir in Path("/").glob(SERIES_GLOB.lstrip("/")):
        for series_file in series_dir.iterdir():
            modified = series_file.stat().st_mtime
            if modified > newest_time:
                newest_dir = series_dir
                newest_time = modified
    return newest_dir


def find_series_problem(series_dir: Path) -> str | None:
    """
    Returns why the series can't be shown, or None when every commit is ready.

    :param series_dir: Directory holding the series files.
    """
    numbers = queued_numbers(series_dir)
    if not numbers:
        return f"No queued commits in {series_dir}."

    for number in numbers:
        if not (series_dir / f"{number}.subjects").exists():
            return f"No subjects file for commit {number} in {series_dir}."
    return None


def queued_numbers(series_dir: Path) -> list[int]:
    """
    Returns the queued commits' positions in series order.

    :param series_dir: Directory holding the series files.
    """
    numbers: list[int] = []
    for path in series_dir.iterdir():
        if path.name.isdigit():
            numbers.append(int(path.name))
    return sorted(numbers)


def find_session_tty() -> str | None:
    """Returns the /dev path of the nearest ancestor's terminal, the session's, or None."""
    # Walk up from the parent: the shell Claude runs commands in has no terminal,
    # but the claude process above it keeps the tab's.
    pid = os.getppid()
    while pid > 1:
        parent, tty = subprocess.check_output(
            ["ps", "-o", "ppid=,tty=", "-p", str(pid)],
            text=True,
        ).split()
        if tty.startswith("tty"):
            return f"/dev/{tty}"
        elif tty != "??":
            return f"/dev/tty{tty}"
        pid = int(parent)
    return None


def open_in_new_window(series_dir: Path) -> int:
    """
    Opens the picker in a new Ghostty window that answers the calling session.

    :param series_dir: Directory holding the series files.
    :return: Exit status for the caller.
    """
    session_tty = find_session_tty()
    if session_tty is None:
        print("No terminal above this process to send the reply to.", file=sys.stderr)
        return 1

    picker_command = shlex.join(
        [
            sys.executable,
            str(Path(__file__).resolve()),
            "--reply-tty",
            session_tty,
            str(series_dir),
        ],
    )
    subprocess.run(
        ["osascript", "-", picker_command],
        input=OPEN_WINDOW_SCRIPT,
        text=True,
        check=True,
    )
    print(f"Opened the picker; its reply goes to {session_tty}.")
    return 0


def send_reply(
    reply_tty: str,
    reply: str,
) -> None:
    """
    Refocuses the session's terminal and types the reply into it.

    Falls back to the clipboard when no Ghostty terminal owns the tty anymore.

    :param reply_tty: /dev path of the session's terminal (e.g. "/dev/ttys005").
    :param reply: Picks to type (e.g. "c1 c5 c8"); empty only refocuses.
    """
    result = subprocess.run(
        ["osascript", "-", reply_tty, reply],
        input=SEND_REPLY_SCRIPT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.stdout.strip() != "sent" and reply:
        subprocess.run(["pbcopy"], input=reply, text=True, check=True)


def main() -> int:
    """Loads the queued series, runs the picker and hands back the reply."""
    parser = argparse.ArgumentParser(description="Pick one subject per queued commit.")
    parser.add_argument(
        "series_dir",
        nargs="?",
        type=Path,
        help="Series directory; the most recently updated one when omitted.",
    )
    parser.add_argument(
        "--new-window",
        action="store_true",
        help="Open in a new Ghostty window that types the reply into this terminal.",
    )
    parser.add_argument(
        "--reply-tty",
        help="Terminal to refocus and type the reply into, set by --new-window.",
    )
    arguments = parser.parse_args()

    series_dir = arguments.series_dir or find_newest_series_dir()
    if series_dir is None:
        print(f"No queued series under {SERIES_GLOB}.", file=sys.stderr)
        return 1

    problem = find_series_problem(series_dir)
    if problem is not None:
        print(problem, file=sys.stderr)
        return 1
    elif arguments.new_window:
        return open_in_new_window(series_dir)

    commits = [QueuedCommit.load(series_dir=series_dir, number=number) for number in queued_numbers(series_dir)]
    picker = SeriesPicker(commits=commits)
    reply = curses.wrapper(picker.run)
    if arguments.reply_tty is not None:
        send_reply(
            reply_tty=arguments.reply_tty,
            reply=reply or "",
        )
    elif reply is not None:
        subprocess.run(["pbcopy"], input=reply, text=True, check=True)
        print(f"📎 Copied to your clipboard; paste at the Claude prompt: {reply}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
