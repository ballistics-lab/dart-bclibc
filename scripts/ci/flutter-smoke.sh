#!/usr/bin/env bash
# Runs `flutter test` in a throwaway Flutter project that depends on the local
# bclibc package: proves the build hook compiles the bundled sources and the
# @Native bindings resolve under `flutter test` (the case that used to need a
# hand-built library and a package: URI lookup).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
flutter create --empty --project-name smoke --platforms linux . >/dev/null
flutter pub add "bclibc:{\"path\":\"$ROOT/dart\"}" >/dev/null

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
