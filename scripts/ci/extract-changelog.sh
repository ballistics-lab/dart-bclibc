#!/usr/bin/env bash
# Prints the release-notes body for $1 from the CHANGELOG.md at $2 -- the
# section under "## [<version>]", falling back to "## [Unreleased]" if
# there's no exact match (forgetting to rename it before tagging is a
# common, easy slip). Prints nothing (exit 0) if neither is found; the
# caller decides whether that's fatal.
#
# Used against dart/CHANGELOG.md -- the source of truth for release notes
# (dart_bclibc and dart_bclibc_flutter are versioned/released in lockstep,
# see that file's own header, but flutter/CHANGELOG.md's own entries are
# usually much thinner, so GitHub Release notes are drawn from dart/'s).
#
# Try it locally, e.g.:
#   ./scripts/ci/extract-changelog.sh Unreleased dart/CHANGELOG.md
set -euo pipefail

VERSION="${1:?usage: extract-changelog.sh <version> <changelog-file>}"
CHANGELOG="${2:?usage: extract-changelog.sh <version> <changelog-file>}"

extract_section() {
    # $1: heading to match inside "## [...]", already regex-escaped by the caller.
    awk "/^## \[$1\]/{found=1; next} /^## \[/{if(found) exit} /^\[.+\]:/{if(found) exit} found{print}" \
        "$CHANGELOG" | sed -e '/./,$!d' -e 's/[[:space:]]*$//'
}

# Escape dots -- an unescaped "." in awk's regex matches any character, and
# every real version has some.
V_RE="${VERSION//./\\.}"

notes="$(extract_section "$V_RE")"
if [ -z "$notes" ]; then
    echo "No changelog entry for $VERSION in $CHANGELOG -- trying [Unreleased]." >&2
    notes="$(extract_section 'Unreleased')"
fi

printf '%s' "$notes"
