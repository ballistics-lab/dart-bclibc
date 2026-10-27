#!/usr/bin/env bash
# Builds (or tests) a throwaway Flutter project that depends on the local
# bclibc package and references the engine, then checks that the library the
# build hook compiled actually ended up in the build output.
#
#   scripts/ci/flutter-smoke.sh [test|linux|windows|android|web]
#
# `test` runs `flutter test` (the case that used to need a hand-built library
# and a package: URI lookup); the others run the release `flutter build` of that
# target, which is what ebalistyka does. The app must call BcLibC.open(): code
# assets are tree-shaken, so an unreferenced library would not be bundled.
set -euo pipefail

TARGET="${1:-test}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && (pwd -W 2>/dev/null || pwd))"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

case "$TARGET" in
  test) PLATFORMS=linux ;;
  *) PLATFORMS="$TARGET" ;;
esac

cd "$TMP"
flutter create --empty --project-name smoke --platforms "$PLATFORMS" . >/dev/null
flutter pub add "bclibc:{\"path\":\"$ROOT\"}" >/dev/null

if [ "$TARGET" = web ]; then
  # The web backend is BcLibCWeb (wasm); AsyncCalculator is the API on every target.
  cat > lib/main.dart <<'DART'
import 'package:bclibc/bclibc.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(Directionality(
    textDirection: TextDirection.ltr,
    child: Text('${AsyncCalculator.new}'),
  ));
}
DART
else
  # Referencing the engine is what makes the build bundle the native asset.
  cat > lib/main.dart <<'DART'
import 'package:bclibc/bclibc.dart';
import 'package:flutter/widgets.dart';

void main() {
  final energy = BcLibC.open().calculateEnergy(168.0, 2700.0);
  runApp(Directionality(
    textDirection: TextDirection.ltr,
    child: Text('E=$energy ${AsyncCalculator.new}'),
  ));
}
DART
fi

have() { # have <description> <find-expression...>
  local what="$1"; shift
  if [ -n "$("$@" 2>/dev/null | head -1)" ]; then echo "OK: $what"; else echo "MISSING: $what" >&2; exit 1; fi
}

case "$TARGET" in
  test)
    mkdir -p test
    cat > test/smoke_test.dart <<'DART'
import 'package:bclibc/bclibc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native engine loads and solves under flutter test', () {
    final bc = BcLibC.open();
    expect(bc.calculateEnergy(168.0, 2700.0), greaterThan(0));
  });

  test('AsyncCalculator is available', () {
    expect(AsyncCalculator.new, isNotNull);
  });
}
DART
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
