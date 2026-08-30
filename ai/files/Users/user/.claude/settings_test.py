"""
Regression tests for Claude Code settings files.

Two layers run over every settings file named on the command line. The shape
layer asserts invariants on the JSON itself: code-point-sorted keys, no
wildcard early enough in an allow rule to swallow smuggled options, no rule
sitting in two sections at once, and a hook script on disk behind every
configured hook command. The behavior layer replays a table of commands
through a small re-implementation of the documented rule matching and asserts
which outcome each command lands on, so a blanket allow pasted back in turns
the table red.

That re-implementation approximates the real matcher (deny then ask then
allow, `*` as any run of characters, `:*` as a trailing wildcard, subcommands
split on shell separators) and can drift from it. Keep it small enough to
audit by eye. It reads the settings file's own rules, so the behavior table
lives beside each settings file as `settings_test_cases.json` and is skipped
when that file is absent.

    Usage:
        python settings_test.py [<settings.json> ...]

    Example:
        python ai/files/Users/user/.claude/settings_test.py
"""

import json
import os
import re
import sys
from functools import lru_cache
from pathlib import Path

# Waive the option-smuggling check for rules that predate it.
# Keep each entry printing a WAIVE line until the rule pins an exact path.
WAIVED_ALLOW_RULES = {
    "Bash(git -C * checkout *)": "worktree skills fast-forward the main checkout",
    "Bash(git -C * merge *)": "worktree skills fast-forward the main checkout",
    "Bash(git -C * merge-base *)": "worktree skills fast-forward the main checkout",
    "Bash(git -C * stash *)": "worktree skills stash around the fast-forward",
}

# Map the installed ~/.claude/ prefix back to this repository.
# Cover every spelling a hook command uses for the home directory.
HOOK_PATH_PREFIXES = (
    "${HOME}/.claude/",
    "$HOME/.claude/",
    "~/.claude/",
)

# Split on every separator Claude Code treats as a subcommand boundary.
# List the two-character operators first so they win over their prefixes.
SEPARATOR_PATTERN = re.compile(r"\|\||&&|\|&|;|\||&|\n")

SECTIONS = ("deny", "ask", "allow")


@lru_cache(maxsize=None)
def glob_to_regex(pattern):
    """
    Compiles a permission-rule pattern into an anchored regex.

    Treats `*` as any run of characters. A trailing ` *` or `:*` becomes
    "optional arguments may follow", so `Bash(git log *)` covers a bare
    `git log` the way the permission dialog's saved prefix rules do.

    :param pattern: Rule body without the tool wrapper (e.g. `git log *`).
    :return: Compiled regex anchored at both ends.
    """
    if pattern.endswith(":*"):
        pattern = pattern[:-2] + " *"
    tail = r"\Z"
    if pattern.endswith(" *"):
        pattern = pattern[:-2]
        tail = r"(\s.*)?\Z"
    body = ".*".join(re.escape(part) for part in pattern.split("*"))
    return re.compile(body + tail)


def bash_patterns(rules):
    """
    Returns the pattern bodies of the `Bash(...)` rules in one section.

    :param rules: Permission rules from a single section (e.g. the allow list).
    :return: Pattern bodies with the `Bash(` wrapper stripped.
    """
    patterns = []
    for rule in rules:
        if rule.startswith("Bash(") and rule.endswith(")"):
            patterns.append(rule[len("Bash(") : -1])
    return patterns


def split_subcommands(command):
    """
    Splits a command line into the parts matched independently.

    :param command: Full command line (e.g. `git log && npm test`).
    :return: Stripped, non-empty subcommand strings.
    """
    subcommands = []
    for part in SEPARATOR_PATTERN.split(command):
        part = part.strip()
        if part:
            subcommands.append(part)
    return subcommands


def matches_section(subcommand, rules):
    """
    Reports whether a subcommand matches any Bash rule in one section.

    :param subcommand: Single command with no shell separators.
    :param rules: Permission rules from a single section.
    :return: True when at least one rule matches.
    """
    for pattern in bash_patterns(rules):
        if glob_to_regex(pattern).match(subcommand):
            return True
    return False


def evaluate(command, permissions):
    """
    Returns the outcome a rule set gives a command.

    Follows the documented precedence: a matching deny rule wins over
    everything, a matching ask rule wins over an allow rule, and a compound
    command is only allowed outright when every subcommand matches an allow
    rule on its own.

    :param command: Full command line to evaluate.
    :param permissions: The `permissions` object from a settings file.
    :return: One of "deny", "ask", "allow", "unmatched".
    """
    subcommands = split_subcommands(command)
    if not subcommands:
        return "unmatched"
    for subcommand in subcommands:
        if matches_section(subcommand, permissions.get("deny", [])):
            return "deny"
    for subcommand in subcommands:
        if matches_section(subcommand, permissions.get("ask", [])):
            return "ask"
    for subcommand in subcommands:
        if not matches_section(subcommand, permissions.get("allow", [])):
            return "unmatched"
    return "allow"


def wildcard_reaches_options(pattern):
    """
    Reports whether a `*` sits early enough to swallow inserted options.

    A wildcard in the final token can only extend the command's arguments. One
    in any earlier token also spans the option slots, so `git -C * checkout *`
    matches `git -C /tmp -c core.pager=<command> checkout master`.

    :param pattern: Rule body without the tool wrapper (e.g. `git -C * merge *`).
    :return: True when a non-final token carries a wildcard.
    """
    tokens = pattern.split(" ")
    for token in tokens[:-1]:
        if "*" in token:
            return True
    return False


def hook_commands(settings):
    """
    Returns every configured hook command in a settings file.

    :param settings: Parsed settings file.
    :return: Command strings from the `hooks` blocks and the status line.
    """
    commands = []
    for matchers in settings.get("hooks", {}).values():
        for matcher in matchers:
            for hook in matcher.get("hooks", []):
                command = hook.get("command")
                if command:
                    commands.append(command)
    status_line = settings.get("statusLine", {}).get("command")
    if status_line:
        commands.append(status_line)
    return commands


def resolve_hook_script(command, settings_dir):
    """
    Returns the repository path a hook command runs, when it names one.

    Rewrites the installed `~/.claude/` prefix to the directory holding the
    settings file, so the check reads the tracked script rather than the
    symlink an install put in the home directory.

    :param command: Hook command string, arguments included.
    :param settings_dir: Directory holding the settings file being checked.
    :return: Path to the script, or None when the command names no path.
    """
    script = command.split()[0]
    for prefix in HOOK_PATH_PREFIXES:
        if script.startswith(prefix):
            return settings_dir / script[len(prefix) :]
    return None


def check_key_order(node, label, results):
    """
    Records whether every object in a settings file has code-point-sorted keys.

    :param node: Parsed JSON value to walk.
    :param label: Dotted path of `node`, used in the result line.
    :param results: Result list to append to.
    :return: None.
    """
    if isinstance(node, dict):
        keys = list(node.keys())
        if keys == sorted(keys):
            results.append(("PASS", f"keys sorted: {label}", ""))
        else:
            results.append(("FAIL", f"keys sorted: {label}", f"got {keys}"))
        for key, value in node.items():
            check_key_order(value, f"{label}.{key}", results)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            check_key_order(value, f"{label}[{index}]", results)


def check_shape(settings, settings_dir, results):
    """
    Records the shape invariants for one settings file.

    :param settings: Parsed settings file.
    :param settings_dir: Directory holding that settings file.
    :param results: Result list to append to.
    :return: None.
    """
    check_key_order(settings, "(root)", results)

    permissions = settings.get("permissions", {})
    for section in SECTIONS:
        rules = permissions.get(section, [])
        if rules != sorted(rules):
            results.append(("FAIL", f"{section} sorted", "rules are out of order"))
        elif len(rules) != len(set(rules)):
            results.append(("FAIL", f"{section} sorted", "rules contain a duplicate"))
        else:
            results.append(("PASS", f"{section} sorted", f"{len(rules)} rules"))

    for section in SECTIONS:
        for other in SECTIONS:
            if other == section:
                continue
            overlap = set(permissions.get(section, [])) & set(permissions.get(other, []))
            for rule in sorted(overlap):
                results.append(("FAIL", f"{section} vs {other}", f"{rule} is in both"))

    for rule in permissions.get("allow", []):
        if not rule.startswith("Bash(") or not rule.endswith(")"):
            continue
        if not wildcard_reaches_options(rule[len("Bash(") : -1]):
            results.append(("PASS", f"no option smuggling: {rule}", ""))
        elif rule in WAIVED_ALLOW_RULES:
            results.append(("WAIVE", f"no option smuggling: {rule}", WAIVED_ALLOW_RULES[rule]))
        else:
            results.append(("FAIL", f"no option smuggling: {rule}", "wildcard precedes the subcommand"))

    for command in hook_commands(settings):
        script = resolve_hook_script(command, settings_dir)
        if script is None:
            continue
        if not script.exists():
            results.append(("FAIL", f"hook installed: {script.name}", "no such file"))
        elif not os.access(script, os.X_OK):
            results.append(("FAIL", f"hook installed: {script.name}", "not executable"))
        else:
            results.append(("PASS", f"hook installed: {script.name}", ""))


def check_behavior(cases, permissions, results):
    """
    Records the outcome each table case lands on under one rule set.

    A case carrying a `waived` reason reports WAIVE instead of FAIL when the
    outcome differs, which keeps a known gap visible without failing the suite.

    :param cases: Parsed behavior table entries.
    :param permissions: The `permissions` object from the settings file.
    :param results: Result list to append to.
    :return: None.
    """
    for case in cases:
        actual = evaluate(case["cmd"], permissions)
        expected = case["expected"]
        if actual == expected:
            results.append(("PASS", f"[{actual}] {case['name']}", ""))
        elif case.get("waived"):
            results.append(("WAIVE", f"[{actual}] {case['name']}", case["waived"]))
        else:
            results.append(("FAIL", case["name"], f"expected={expected} got={actual}"))


def run(settings_path, results):
    """
    Runs both layers over one settings file.

    :param settings_path: Path to the settings file to check.
    :param results: Result list to append to.
    :return: None.
    """
    settings = json.loads(settings_path.read_text())
    check_shape(settings, settings_path.parent, results)

    cases_path = settings_path.with_name(f"{settings_path.stem}_test_cases.json")
    if cases_path.exists():
        cases = json.loads(cases_path.read_text())
        check_behavior(cases, settings.get("permissions", {}), results)


def main(argv):
    """
    Checks each settings file named on the command line.

    :param argv: Settings file paths; defaults to the one beside this script.
    :return: Process exit status, 1 when any check failed.
    """
    paths = [Path(arg) for arg in argv]
    if not paths:
        paths = [Path(__file__).with_name("settings.json")]

    failures = 0
    waivers = 0
    for path in paths:
        results = []
        run(path, results)
        counts = {"PASS": 0, "FAIL": 0, "WAIVE": 0}
        print(f"== {path} ==")
        for status, label, detail in results:
            counts[status] += 1
            if status == "PASS":
                continue
            suffix = f"  ({detail})" if detail else ""
            print(f"  {status:<6}{label}{suffix}")
        print(f"  {counts['PASS']} passed, {counts['FAIL']} failed, {counts['WAIVE']} waived")
        failures += counts["FAIL"]
        waivers += counts["WAIVE"]

    # Report the waiver tally last so a green run still says what it excused.
    if waivers:
        print(f"\n{waivers} waived check(s) still need a real fix.")
    if failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
