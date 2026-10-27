#!/usr/bin/env bash
# Tests or builds example/ (a Flutter app that depends on the local bclibc by
# path and references the engine) for one target, then checks that the library
# the build hook compiled actually ended up in the build output.
#
#   scripts/ci/flutter-smoke.sh [test|linux|macos|windows|android|web]
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
  local want="$1" exe="$2" out code=0 runner=() limit=()
  # macOS has no `timeout` (coreutils installs it as `gtimeout`).
  if command -v timeout >/dev/null; then limit=(timeout 120)
  elif command -v gtimeout >/dev/null; then limit=(gtimeout 120); fi
  [ -n "${CI:-}" ] || { echo "skip: self-test run (set CI=1 to run the built app)"; return 0; }
  out="$(mktemp -u)"
  if [ "$(uname -s)" = Linux ] && command -v xvfb-run >/dev/null; then runner=(xvfb-run -a); fi
  BCLIBC_EXAMPLE_SELFTEST=1 BCLIBC_EXAMPLE_SELFTEST_OUT="$out" \
    ${limit[@]+"${limit[@]}"} ${runner[@]+"${runner[@]}"} "$exe" >/dev/null 2>&1 || code=$?
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
  macos)
    # example/ has no macos/ runner checked in; generate it (keeps lib/ and
    # pubspec.yaml as they are).
    [ -d macos ] || flutter create --platforms=macos --project-name bclibc_example .
    flutter pub get
    flutter build macos --release
    APP="$(find build/macos -type d -name 'bclibc_example.app' | head -1)"
    have "bclibc_ffi library inside the .app" find "$APP" -name '*bclibc_ffi*'
    selftest ok "$APP/Contents/MacOS/bclibc_example"
    find "$APP" -name '*bclibc_ffi*' -exec rm -rf {} +
    selftest fail "$APP/Contents/MacOS/bclibc_example"
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
    # Google Play: 64-bit libraries must be 16 KB page aligned (every LOAD
    # segment), or the app is rejected / fails on 16 KB devices.
    SO="$(mktemp -d)"
    for abi in arm64-v8a x86_64; do
      unzip -p "$APK" "lib/$abi/libbclibc_ffi.so" > "$SO/$abi.so"
      # Every DT_NEEDED must be a system library: nothing else is in the APK.
      if readelf -d "$SO/$abi.so" | grep -q 'libc++_shared'; then
        echo "MISSING: $abi libbclibc_ffi.so needs libc++_shared.so, which is not bundled" >&2; exit 1
      fi
      for align in $(readelf -lW "$SO/$abi.so" | awk '$1=="LOAD" {print $NF}'); do
        [ $((align)) -ge 16384 ] || { echo "MISSING: $abi LOAD segment aligned to $align, need >= 0x4000 (16 KB)" >&2; exit 1; }
      done
      echo "OK: $abi libbclibc_ffi.so is 16 KB page aligned"
    done
    ;;
  web)
    flutter build web --release
    have "build/web/main.dart.js" find build/web -name 'main.dart.js'
    ;;
  *) echo "unknown target: $TARGET" >&2; exit 2 ;;
esac
