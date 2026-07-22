#!/usr/bin/env python3
"""Prepares a release commit for the maintainer to review and push by hand
-- run this locally BEFORE tagging, never from CI. release.yml's
verify-release job then only checks that the tag it was pushed for already
carries a consistent version/changelog everywhere; it refuses to publish
otherwise instead of trying to auto-fix things during the release run (that
auto-fix pattern -- bumping versions and pushing a commit to main *after*
the tag already exists -- is exactly what can make a downstream tool that
derives its version from `git describe` see "N commits past the tag" and
reject it; dart_bclibc doesn't use that scheme today, but there's no upside
to inviting the failure mode).

dart_bclibc and dart_bclibc_flutter are versioned in lockstep: one VERSION,
one `vX.Y.Z` tag, for both packages every release.

What this script does, all as uncommitted working-tree edits for you to
review with `git diff` and commit yourself:
  1. Renames dart/CHANGELOG.md's "## [Unreleased]" heading to
     "## [VERSION] - DATE" and adds a fresh empty "## [Unreleased]" above
     it. Fails if that section is empty (nothing to release).
  2. Does the same to flutter/CHANGELOG.md -- if its "## [Unreleased]" is
     empty (common: most releases don't touch flutter/), inserts a one-line
     "version bump only" note instead of failing.
  3. Updates the reference-style links at the bottom of both CHANGELOG.md
     files (adds "[VERSION]: .../compare/PREV...VERSION" or
     ".../releases/tag/VERSION" for the first release, repoints
     "[Unreleased]").
  4. Bumps dart/pubspec.yaml's version, flutter/pubspec.yaml's version, and
     flutter/pubspec.yaml's `dart_bclibc: ^...` dependency constraint, all
     to VERSION.

It does NOT commit, tag, or push anything -- that's on you, after reviewing
the diff:
    git add -A && git commit -m "chore: prepare release VERSION"
    git push origin main
    git tag vVERSION && git push origin vVERSION

Usage: scripts/ci/prepare_release.py VERSION   (e.g. 1.2.3, no "v" prefix)
"""

import re
import subprocess
import sys
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
REPO_URL = "https://github.com/ballistics-lab/dart-bclibc"

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-.](?:alpha|beta|rc)\.?\d*)?$")
HEADING_RE = re.compile(r"^## \[(?P<version>[^\]]+)\]")
LINK_RE = re.compile(r"^\[(?P<label>[^\]]+)\]:\s")


def fail(msg: str) -> None:
    sys.exit(f"error: {msg}")


def check_clean_tree() -> None:
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if status.strip():
        fail(
            "working tree isn't clean -- commit or stash your changes first "
            "so this script's edits are easy to review on their own."
        )


def update_changelog(path: Path, version: str, *, allow_empty: bool) -> None:
    lines = path.read_text().splitlines()

    unreleased_idx = next(
        (i for i, line in enumerate(lines) if line.strip() == "## [Unreleased]"),
        None,
    )
    if unreleased_idx is None:
        fail(f"{path.relative_to(REPO_ROOT)} has no '## [Unreleased]' heading to rename.")

    body = lines[unreleased_idx + 1 :]
    next_heading_idx = next(
        (i for i, line in enumerate(body) if HEADING_RE.match(line)), len(body)
    )
    unreleased_body = [line for line in body[:next_heading_idx] if line.strip()]

    insert = ["## [Unreleased]", ""]
    if not unreleased_body:
        if not allow_empty:
            fail(
                f"{path.relative_to(REPO_ROOT)}'s '## [Unreleased]' section is "
                "empty -- add the release's changes there first."
            )
        insert += [
            f"## [{version}] - {date.today().isoformat()}",
            "",
            f"_No changes -- version bumped to stay in lockstep with the other "
            f"package._",
            "",
        ]
    else:
        insert += [f"## [{version}] - {date.today().isoformat()}", ""]

    prev_version = None
    m = HEADING_RE.match(body[next_heading_idx]) if next_heading_idx < len(body) else None
    if m:
        prev_version = m.group("version")

    lines[unreleased_idx : unreleased_idx + 1] = insert

    link_idx = next((i for i, line in enumerate(lines) if LINK_RE.match(line)), None)
    if link_idx is None:
        fail(f"{path.relative_to(REPO_ROOT)} has no reference-style links ('[X]: url') to update.")

    new_compare = (
        f"[{version}]: {REPO_URL}/compare/v{prev_version}...v{version}"
        if prev_version
        else f"[{version}]: {REPO_URL}/releases/tag/v{version}"
    )
    new_links = [f"[Unreleased]: {REPO_URL}/compare/v{version}...HEAD", new_compare]

    if LINK_RE.match(lines[link_idx]).group("label") == "Unreleased":
        lines[link_idx : link_idx + 1] = new_links
    else:
        lines[link_idx:link_idx] = new_links

    path.write_text("\n".join(lines) + "\n")
    print(f"Updated {path.relative_to(REPO_ROOT)}")


def bump_field(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        fail(f"couldn't find a version field to bump in {path.relative_to(REPO_ROOT)}.")
    path.write_text(new_text)
    print(f"Bumped {path.relative_to(REPO_ROOT)}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: scripts/ci/prepare_release.py VERSION  (e.g. 1.2.3)")
    version = sys.argv[1].lstrip("v")
    if not VERSION_RE.match(version):
        fail(f"'{version}' doesn't look like a version (expected e.g. 1.2.3 or 1.2.3-rc.1).")

    check_clean_tree()

    update_changelog(REPO_ROOT / "dart" / "CHANGELOG.md", version, allow_empty=False)
    update_changelog(REPO_ROOT / "flutter" / "CHANGELOG.md", version, allow_empty=True)

    bump_field(REPO_ROOT / "dart" / "pubspec.yaml", r"^version: .*$", f"version: {version}")
    bump_field(REPO_ROOT / "flutter" / "pubspec.yaml", r"^version: .*$", f"version: {version}")
    bump_field(
        REPO_ROOT / "flutter" / "pubspec.yaml",
        r"^(\s*dart_bclibc: )\^[^\s]+$",
        rf"\g<1>^{version}",
    )

    print(
        f"\nReview with `git diff`, then:\n"
        f"  git add -A && git commit -m 'chore: prepare release {version}'\n"
        f"  git push origin main\n"
        f"  git tag v{version} && git push origin v{version}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
