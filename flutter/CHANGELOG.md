# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`bclibc_flutter` is versioned in lockstep with `bclibc` — both
packages are released together under the same tag/version.

## [Unreleased]

### Changed

- Pin `bclibc` to `v2.0.0-beta.2` and rebuild the web WASM assets with its
  Cash-Karp and Dormand-Prince integrators.

## [0.2.3] - 2026-09-15

### Changed

- **Breaking:** package renamed from `dart_bclibc_flutter` to `bclibc_flutter`,
  in lockstep with the `dart_bclibc` → `bclibc` rename (see its own
  `CHANGELOG.md`). Update your `pubspec.yaml` dependency and every
  `package:dart_bclibc_flutter/...` import.

### Migration

- `dependencies: { dart_bclibc_flutter: ^0.2.2 }` → `dependencies: { bclibc_flutter: ^0.2.3 }`
- `import 'package:dart_bclibc_flutter/bclibc.dart';` → `import 'package:bclibc_flutter/bclibc.dart';`
  (and likewise for every other `package:dart_bclibc_flutter/...` import).
- iOS/macOS: CocoaPods caches pod specs by name — run `pod deintegrate` (or
  delete `ios/Pods`, `ios/Podfile.lock` / `macos/Pods`, `macos/Podfile.lock`)
  before your next `pod install` so it picks up `bclibc_flutter.podspec`
  instead of the old `dart_bclibc.podspec`.

## [0.2.2] - 2026-09-15

### Changed
- Bump `bclibc` to `0.2.2` — fixes `Distance.centimeter()` (see its
  `CHANGELOG.md`).

## [0.2.1] - 2026-09-14

### Changed
- Pin `bclibc` to `v1.1.8`
- Rebuild web wasm assets from `bclibc` `v1.1.8` (emsdk 6.0.9); adds Velocity Verlet on web

## [0.2.0] - 2026-07-24

### Changed
- Pin `bclibc` to `v1.1.7`

## [0.2.0-beta.3] - 2026-07-23

### Fixed
- Flutter package facade filename

## [0.2.0-beta.2] - 2026-07-26

### Added
- Update flutter package's umbrella

## [0.2.0-beta.1] - 2026-07-22

### Added

- Initial release, split out of `bclibc` (see its `CHANGELOG.md` for the
  full history predating this split). Bundles native platform builds for
  Android/iOS/Linux/macOS/Windows and Web/WebAssembly support, plus
  `AsyncCalculator`. Re-exports everything from `bclibc`.

[Unreleased]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.3...HEAD
[0.2.3]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.3...v0.2.0
[0.2.0-beta.3]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.2...v0.2.0-beta.3
[0.2.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.1...v0.2.0-beta.2
[0.2.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/releases/tag/v0.2.0-beta.1
