#!/usr/bin/env bash
# Tests or builds example/ (a Flutter app that depends on the local bclibc by
# path and references the engine) for one target, then checks that the library
# the build hook compiled actually ended up in the build output.
#
#   scripts/ci/flutter-smoke.sh [test|linux|windows|android|web]
#
# `test` runs `flutter test` (the case that used to need a hand-built library
# and a package: URI lookup); the others run the release `flutter build` of that
# target, which is what ebalistyka does. The app must use the engine: code
# assets are tree-shaken, so an unreferenced library would not be bundled.
set -euo pipefail

TARGET="${1:-test}"
cd "$(dirname "${BASH_SOURCE[0]}")/../../example"

flutter pub get

# Runs the built example in self-test mode (it loads the engine, solves a shot,
# writes the result to a file and exits 0, or exits 1 with the reason). With
# `fail`, the caller removed the library first, so open() has to fail loudly.
# Only in CI: on Linux it opens a window, which needs a display (xvfb).
selftest() { # selftest <ok|fail> <exe>
  local want="$1" exe="$2" out code=0 runner=()
  [ -n "${CI:-}" ] || { echo "skip: self-test run (set CI=1 to run the built app)"; return 0; }
  out="$(mktemp -u)"
  if [ "$(uname -s)" = Linux ] && command -v xvfb-run >/dev/null; then runner=(xvfb-run -a); fi
  BCLIBC_EXAMPLE_SELFTEST=1 BCLIBC_EXAMPLE_SELFTEST_OUT="$out" \
    timeout 120 ${runner[@]+"${runner[@]}"} "$exe" >/dev/null 2>&1 || code=$?
  local msg; msg="$(cat "$out" 2>/dev/null || true)"
  if [ "$want" = ok ]; then
    if [ "$code" -eq 0 ] && [[ "$msg" == "bclibc self-test ok"* ]]; then echo "OK: the built app loaded the engine and solved a shot"
    else echo "FAILED: the built app could not run the engine (exit $code): $msg" >&2; exit 1; fi
  else
    if [ "$code" -ne 0 ] && [[ "$msg" == *"Could not load the native bclibc library"* ]]; then echo "OK: with the library removed the app fails fast: ${msg%%$'\n'*}"
    else echo "FAILED: the app did not fail fast without the library (exit $code): $msg" >&2; exit 1; fi
  fi
}

have() { # have <description> <find-expression...>
  local what="$1"; shift
  if [ -n "$("$@" 2>/dev/null | head -1)" ]; then echo "OK: $what"; else echo "MISSING: $what" >&2; exit 1; fi
}

case "$TARGET" in
  test)
    flutter test
    ;;
  linux)
    flutter build linux --release
    have "libbclibc_ffi.so in the bundle" find build/linux -name 'libbclibc_ffi.so'
    BUNDLE="$(dirname "$(find build/linux -type f -name bclibc_example | head -1)")"
    selftest ok "$BUNDLE/bclibc_example"
    rm -f "$BUNDLE"/lib/libbclibc_ffi.so
    selftest fail "$BUNDLE/bclibc_example"
    ;;
  windows)
    flutter build windows --release
    have "bclibc_ffi.dll next to the exe" find build/windows -name 'bclibc_ffi.dll'
    EXE="$(find build/windows -type f -name bclibc_example.exe | head -1)"
    selftest ok "$EXE"
    rm -f "$(dirname "$EXE")/bclibc_ffi.dll"
    selftest fail "$EXE"
    ;;
  android)
    flutter build apk --release
    APK="$(find build/app/outputs -name '*.apk' | head -1)"
    for abi in arm64-v8a armeabi-v7a x86_64; do
      have "lib/$abi/libbclibc_ffi.so in the APK" unzip -l "$APK" "lib/$abi/libbclibc_ffi.so"
    done
    ;;
  web)
    flutter build web --release
    have "build/web/main.dart.js" find build/web -name 'main.dart.js'
    ;;
  *) echo "unknown target: $TARGET" >&2; exit 2 ;;
esac
