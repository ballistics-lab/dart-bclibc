#!/usr/bin/env bash
# Regression check for "BcLibC.open() must fail when the native library cannot be
# loaded". The @Native bindings resolve the library lazily, so without an eager
# probe open() succeeds and the failure only appears at the first calculation
# (a startup check such as `try { BcLibC.open(); } catch -> exit(1)` would never
# fire).
#
# Builds a tiny console app that depends on this package, runs it from the
# build bundle (open() must succeed), deletes libbclibc_ffi from the bundle and
# runs it again (open() must throw).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

mkdir bin
cat > pubspec.yaml <<YAML
name: missing_library_check
environment:
  sdk: ^3.11.4
dependencies:
  bclibc:
    path: $ROOT
YAML
cat > bin/check.dart <<'DART'
import 'dart:io';

import 'package:bclibc/bclibc.dart';

void main() {
  try {
    BcLibC.open();
  } catch (e) {
    stdout.writeln('open() threw: $e');
    return;
  }
  stdout.writeln('open() ok');
}
DART

dart pub get --no-example >/dev/null
dart build cli --target bin/check.dart -o out >/dev/null
EXE="$(find out -type f -name check | head -1)"

OUT="$("$EXE" 2>&1 || true)"
echo "intact bundle: $OUT"
[ "$OUT" = "open() ok" ] || { echo "ERROR: open() should succeed with the library present" >&2; exit 1; }

find out -name 'libbclibc_ffi.*' -delete
OUT="$("$EXE" 2>&1 || true)"
echo "library removed: ${OUT%%$'\n'*}"
case "$OUT" in
  "open() threw: "*) echo "OK: open() fails fast when the library is missing" ;;
  *) echo "ERROR: open() did not throw with the library removed:" >&2; echo "$OUT" >&2; exit 1 ;;
esac
