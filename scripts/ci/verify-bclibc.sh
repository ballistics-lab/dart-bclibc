#!/usr/bin/env bash
# Verifies every place in this repo that pins a bclibc version agrees on the
# same one:
#
#   1. dart/bclibc and flutter/bclibc submodule gitlinks point at the same commit
#   2. BCLIBC_VERSION in flutter/{src,linux,windows}/CMakeLists.txt == that commit
#   3. flutter/assets/wasm/bclibc_ffi.wasm was built from that commit (its
#      embedded `git describe` version string, see bclibc/build_wasm.sh)
#   4. the latest "Pin `bclibc` to `vX.Y.Z`" line in dart/ and flutter/
#      CHANGELOG.md names a tag that resolves to that commit
#
# Reads everything from the git index, not the working tree, so as a
# pre-commit hook it checks exactly what is about to be committed (and in CI,
# right after checkout, the index is HEAD). Doesn't need the submodules
# checked out: tags are resolved from a local submodule checkout when there is
# one, else via `git ls-remote` against the URL in .gitmodules.
#
# Checks 3–4 need a tag lookup; if that's impossible (offline, no local tags)
# they're skipped with a warning locally, but fail when CI is set.
#
# Usage:
#   scripts/ci/verify-bclibc.sh        # or: make verify-bclibc
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

CMAKE_FILES=(flutter/src/CMakeLists.txt flutter/linux/CMakeLists.txt flutter/windows/CMakeLists.txt)
WASM=flutter/assets/wasm/bclibc_ffi.wasm
CHANGELOGS=(dart/CHANGELOG.md flutter/CHANGELOG.md)

errors=0
fail() { echo "error: $*" >&2; errors=$((errors + 1)); }
warn() { echo "warning: $*" >&2; }
skip_or_fail() { if [[ -n "${CI:-}" ]]; then fail "$@"; else warn "$* (skipped locally, fatal in CI)"; fi; }

# Staged gitlink sha of a submodule path.
gitlink() { git ls-files -s -- "$1" | awk '$1 == "160000" { print $2 }'; }
# Staged content of a regular file.
staged() { git show ":$1"; }

# ── 1. submodules ─────────────────────────────────────────────────────────────
dart_ref="$(gitlink dart/bclibc)"
flutter_ref="$(gitlink flutter/bclibc)"
[[ -n "$dart_ref" ]] || { echo "error: dart/bclibc is not a submodule in the index" >&2; exit 1; }
if [[ "$dart_ref" != "$flutter_ref" ]]; then
    fail "dart/bclibc ($dart_ref) and flutter/bclibc (${flutter_ref:-missing}) point at different commits (run: make sync-bclibc)"
fi
REF="$dart_ref"

# ── 2. CMake FetchContent pins ────────────────────────────────────────────────
for f in "${CMAKE_FILES[@]}"; do
    pinned="$(staged "$f" | sed -nE 's/^[[:space:]]*set\(BCLIBC_VERSION "([^"]*)"\).*/\1/p' | head -1)"
    if [[ -z "$pinned" ]]; then
        fail "$f: no set(BCLIBC_VERSION \"...\") found"
    elif [[ "$pinned" != "$REF" ]]; then
        fail "$f: BCLIBC_VERSION is $pinned, submodules are at $REF (run: make sync-bclibc)"
    fi
done

# ── tag resolution helper ─────────────────────────────────────────────────────
BCLIBC_URL="$(git config -f .gitmodules submodule.dart/bclibc.url)"

# Prints the commit sha tag $1 points at, or nothing if it can't be resolved.
resolve_tag() {
    local tag="$1" sub sha
    for sub in dart/bclibc flutter/bclibc; do
        if git -C "$sub" rev-parse --git-dir >/dev/null 2>&1 &&
            sha="$(git -C "$sub" rev-parse -q --verify "refs/tags/${tag}^{commit}" 2>/dev/null)"; then
            echo "$sha"
            return
        fi
    done
    # Annotated tags list both the tag object and a peeled "^{}" line; prefer
    # the peeled (commit) one.
    git ls-remote --tags "$BCLIBC_URL" "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>/dev/null |
        sort -k2 | awk 'END { print $1 }'
}

# Checks that version string $2 (from `git describe --tags`, leading "v"
# stripped) found in $1 refers to $REF.
check_described_version() {
    local where="$1" ver="$2" tag_sha
    if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-g([0-9a-f]+)$ ]]; then
        [[ "$REF" == "${BASH_REMATCH[1]}"* ]] ||
            fail "$where: built from bclibc $ver, submodules are at $REF"
        return
    fi
    tag_sha="$(resolve_tag "v$ver")"
    if [[ -z "$tag_sha" ]]; then
        skip_or_fail "$where: couldn't resolve bclibc tag v$ver"
    elif [[ "$tag_sha" != "$REF" ]]; then
        fail "$where: references bclibc v$ver ($tag_sha), submodules are at $REF"
    fi
}

# ── 3. wasm asset ─────────────────────────────────────────────────────────────
mapfile -t wasm_versions < <(staged "$WASM" |
    LC_ALL=C grep -aoE '(^|[^0-9.])[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+-g[0-9a-f]{7,40})?' |
    sed -E 's/^[^0-9]//' | sort -u)
if [[ ${#wasm_versions[@]} -ne 1 ]]; then
    fail "$WASM: expected exactly one embedded version string, found ${#wasm_versions[@]}: ${wasm_versions[*]:-none}"
else
    check_described_version "$WASM (rebuild: flutter/bclibc/build_wasm.sh)" "${wasm_versions[0]}"
fi

# ── 4. CHANGELOGs ─────────────────────────────────────────────────────────────
for f in "${CHANGELOGS[@]}"; do
    ver="$(staged "$f" | sed -nE 's/.*[Pp]in `bclibc` to `v([^`]+)`.*/\1/p' | head -1)"
    if [[ -z "$ver" ]]; then
        warn "$f: no \"Pin \`bclibc\` to \`vX.Y.Z\`\" entry found"
    else
        check_described_version "$f" "$ver"
    fi
done

if ((errors > 0)); then
    echo "bclibc version check failed with $errors error(s)" >&2
    exit 1
fi
echo "OK: bclibc pinned consistently at $REF"
