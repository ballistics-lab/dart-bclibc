# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0-beta.3] - 2026-07-26

### Fixed
- `bin/build_native.dart` resolved its own package root via `Platform.script`,
  which points at a cached kernel snapshot in the *caller's*
  `.dart_tool/pub/bin/` — not this file's real location in pub-cache — when
  invoked as `dart run dart_bclibc:build_native` from a consuming project
  (as opposed to running it directly from within this repo, which is how it
  was tested for 0.1.0-beta.2). Switched to `Isolate.resolvePackageUri`,
  which goes through the actual `package_config.json` resolution and works
  regardless of pub-cache vs. path dependency vs. snapshot caching.

## [0.1.0-beta.2] - 2026-07-26

### Added
- `bin/build_native.dart` — `dart run dart_bclibc:build_native` builds the
  standalone `libbclibc_ffi` shared library into `build/bclibc/`, for
  consumers running `flutter test`/`dart test`, which never trigger the
  platform build that bundles the library automatically

### Changed
- `Makefile`'s `build` target now delegates to `bin/build_native.dart`
  instead of duplicating the CMake invocation
- CI (`test-submodule`, `test-macos`) builds the native library via
  `dart run bin/build_native.dart` instead of raw CMake commands; dropped
  the now-unused `ninja-build` system dependency from `test-submodule`

## [0.1.0-beta.1] - 2026-07-01

First public release as a standalone package.

### Added
- `BcLibC` — main entry point; open with `BcLibC.open()`
- `BcLibC.integrateShot` — full trajectory integration
- `BcLibC.integrateAtShot` — trajectory integration to a specific intercept key
- `BcLibC.findZeroAngleShot` — barrel elevation for a given zero distance
- `BcLibC.findApexShot` — apex point of a ballistic arc
- `BcLibC.findMaxRangeShot` — maximum range and angle
- `BcLibC.calculateEnergy`, `calculateOgw`, `getCorrection` — utility functions
- `BcShot` — user-facing shot descriptor in natural units; all physics
  conversion (atmosphere density, Coriolis trig, PCHIP drag curve, cant
  sin/cos) delegated to C++ via `BCLIBCFFI_Shot::to_shot_props()`
- `BcTrajectoryRequest`, `BcTrajectoryData`, `BcBaseTrajData`,
  `BcHitResult`, `BcInterception`, `BcMaxRangeResult` — result types
- `BcException` — structured error with per-error-code extras
  (`requestedDistanceFt`, `zeroFindingError`, etc.)
- `BcConfig` — solver tuning parameters (step multiplier, accuracy, limits)
- `BcWind`, `BcDragPoint` — wind and drag table entry value types
- Unit system (`lib/unit.dart`): `Distance`, `Velocity`, `Temperature`,
  `Pressure`, `Angular`, `Weight`, `Energy` with `in_()` / `toDouble()` API
- Smoke-test suite (`test/ffi_test.dart`, `test/unit_test.dart`)
- `Makefile` with `build`, `ffigen`, `test`, `clean` targets
- CI workflow (`.github/workflows/ci.yml`): analyze, submodule build,
  FetchContent build, macOS build, pub.dev dry-run jobs

### Notes
- Platforms: Linux, Windows, Android (arm64-v8a, x86_64), iOS, macOS
- Native library: `libbclibc_ffi.so` / `bclibc_ffi.dll` /
  `libbclibc_ffi.dylib` — compiled from `bclibc/` (v1.1.4, LGPL-3.0)
- CMake build strategy (Linux/Windows/Android):
  1. submodule present → `add_subdirectory` (pub.dev; run `git submodule update --init` before publishing)
  2. pre-installed library found → use it (Flatpak `/app/lib`)
  3. fallback → `FetchContent` from GitHub (git dep via `dart pub get`)

[Unreleased]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.3...HEAD
[0.1.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.2...v0.1.0-beta.3
[0.1.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.1...v0.1.0-beta.2
[0.1.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/releases/tag/v0.1.0-beta.1
