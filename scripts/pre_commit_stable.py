"""
Run pre-commit with `autoupdate` kept from bumping any hook to a prerelease tag.

pre-commit picks the newest tag on each hook's default branch, whatever it is
named, so a plain autoupdate happily moves a hook from `8.0.1` to `9.0.0a3`
(https://github.com/pre-commit/pre-commit/issues/995). This wrapper patches
`pre_commit.git.get_best_candidate_tag` to parse every tag as a PEP 440
version and keep the highest non-prerelease one, falling back to pre-commit's
own pick when no tag parses as a stable version.

Usage:
    python scripts/pre_commit_stable.py autoupdate [autoupdate options]

Example:
    python scripts/pre_commit_stable.py autoupdate --config=.pre-commit-config.yaml
"""

import sys

from packaging.version import InvalidVersion, Version
from pre_commit import git
from pre_commit.git import NO_FS_MONITOR
from pre_commit.main import main as pre_commit_main
from pre_commit.util import cmd_output

_original_get_best_candidate_tag = git.get_best_candidate_tag


def get_best_stable_candidate_tag(rev: str, git_repo: str) -> str:
    """
    Returns the highest non-prerelease PEP 440 tag in a hook's repo clone.

    :param rev: Revision pre-commit already picked (e.g. "9.0.0a3"); only
        handed to the fallback when no tag parses as a stable version.
    :param git_repo: Path to pre-commit's clone of the hook repo.
    :return: Tag name, or pre-commit's own pick when no stable tag exists.
    """
    tags = cmd_output("git", *NO_FS_MONITOR, "tag", "--list", cwd=git_repo)[1].splitlines()

    best: tuple[Version, str] | None = None
    for tag in tags:
        try:
            version = Version(tag)
        except InvalidVersion:
            continue

        if version.is_prerelease:
            continue

        if best is None or version > best[0]:
            best = (version, tag)

    if best is not None:
        return best[1]

    return _original_get_best_candidate_tag(rev, git_repo)


# Patch the module attribute rather than the imported name: `autoupdate` looks
# up `git.get_best_candidate_tag` at call time, so the swap here takes effect.
# Suppress ty's complaint, since it types a module function as that one function.
git.get_best_candidate_tag = get_best_stable_candidate_tag  # ty: ignore[invalid-assignment]


if __name__ == "__main__":
    sys.exit(pre_commit_main(sys.argv[1:]))
