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
    ;;
  windows)
    flutter build windows --release
    have "bclibc_ffi.dll next to the exe" find build/windows -name 'bclibc_ffi.dll'
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
