# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`bclibc_flutter` is versioned in lockstep with `bclibc` — both
packages are released together under the same tag/version.

## [Unreleased]

## [1.0.0] - 2026-10-03

Stable release, covering the whole arc from 0.2.3 through 1.0.0-rc.5. Highlights below; full details are in
the beta/rc entries beneath this one.

### Changed
- **BREAKING (web)**: the web binding loads one bare WebAssembly module, `assets/wasm/bclibc_ffi.wasm`, built by
  bclibc's `make wasm-zig` (no Emscripten, imports nothing), instead of the Emscripten `bclibc_ffi.js` + `.wasm`
  pair. `BcLibCWeb.open({scriptUrl, globalName})` is now `BcLibCWeb.open({wasmUrl})`; the module is about 84 KB
  (was 131 KB with the JS glue) and needs no WebAssembly exception handling since bclibc never throws.
- `AsyncCalculator.fire()` now returns the updated `HitResult` API with exact `records`, physical `events`, and
  scheduled `samples`; `trajectory` remains a deprecated alias for `records`.
- The native library and the web module are built from bclibc's exception-free core: same `BCLIBCFFI_ERR_*`
  codes and messages as before.

### Added
- `BcIntegrationMethod.cashKarp`/`.dormandPrince`/`.tsitouras` available in `AsyncCalculator` on both native and
  WASM engines.
- `AsyncCalculator.aimingSolutionForTarget()` returns vertical hold, windage, and the target-range trajectory
  point through both native and WASM engines.

### Fixed
- Web: `BcLibCWeb` could throw `Cannot perform DataView.prototype.setFloat64 on a detached ArrayBuffer` — it took
  a view of the module's memory before the last allocation, which can grow (and detach) that memory. The view is
  now taken after the last allocation.

### Chores
- Pin `bclibc` to `v2.0.0`

## [1.0.0-rc.5] - 2026-10-01


### Changed
- **BREAKING (web)**: the web binding loads one bare WebAssembly module, `assets/wasm/bclibc_ffi.wasm`, built by bclibc's
  `make wasm-zig` (no Emscripten, imports nothing), instead of the Emscripten `bclibc_ffi.js` + `.wasm` pair.
  `assets/wasm/bclibc_ffi.js` is gone from the package, and `BcLibCWeb.open({scriptUrl, globalName})` is now
  `BcLibCWeb.open({wasmUrl})`. The module is about 84 KB (was 131 KB with the JS glue) and, because bclibc never
  throws, is built without C++ exceptions, so it runs on any browser with WebAssembly: no WebAssembly exception
  handling is needed.
- `make build-wasm` builds with zig (`uv run --with ziglang make build-wasm`); `WASM_TOOLCHAIN=wasi-sdk
  WASI_SDK_PATH=...` builds the same module with wasi-sdk (~1 MB).
- The native library and the web module are built from bclibc's exception-free core (every fallible call returns a
  result that the flat C ABI maps to a `BCLIBCFFI_ERR_*` code): same codes and messages as before.

### Fixed
- `pubspec.yaml` no longer lists the removed `assets/wasm/bclibc_ffi.js` (`flutter analyze`, `flutter test` and
  `dart pub publish --dry-run` failed on the missing asset).
- Web: `BcLibCWeb` could throw `Cannot perform DataView.prototype.setFloat64 on a detached ArrayBuffer`: it took a view
  of the module's memory before allocating the shot, and `malloc` may grow (and so detach) that memory. The small
  module starts with less memory than the old one, so it grows sooner. The view is now taken after the last
  allocation.

### Chores
- Pin `bclibc` to `v2.0.0-rc.4`

## [1.0.0-rc.4] - 2026-09-29

### Chores
- Pin `bclibc` to `v2.0.0-rc.3`

### Changed
- update `pub` deps

## [1.0.0-rc.2] - 2026-09-24

### Chores
- Pin `bclibc` to `v2.0.0-rc.2`

## [1.0.0-rc.1] - 2026-09-22

### Changed

- Pin `bclibc` to `v2.0.0-rc.1` and rebuild the web WASM assets — bclibc
  replaces the embedded RK45 methods' thread-local tolerance/stats API with
  stateful `BCLIBC_CashKarpIntegrator`/`BCLIBC_DormandPrinceIntegrator`/
  `BCLIBC_TsitourasIntegrator` classes internally; no change to the WASM FFI
  surface, which only ever calls the plain `BCLIBCFFI_integrate*` functions,
  unaffected by this.

## [1.0.0-beta.2] - 2026-09-21


### Changed

- Pin `bclibc` to `v2.0.0-beta.8` and rebuild the web WASM assets with the
  adaptive Tsitouras 5(4) integration method.

### Added

- `BcIntegrationMethod.tsitouras` is available in `AsyncCalculator` on both
  native and WASM engines.
- WASM tests covering the Cash-Karp, Dormand-Prince and Tsitouras integrators.

## [1.0.0-beta.1] - 2026-09-17

### Changed

- Pin `bclibc` to `v2.0.0-beta.7` and rebuild the web WASM assets with its
  Cash-Karp and Dormand-Prince integrators plus zero-point FFI exports.
- `AsyncCalculator.fire()` now returns the updated `HitResult` API with
  exact `records`, physical `events`, and scheduled `samples`; `trajectory`
  remains a deprecated alias for `records`.

### Added

- `AsyncCalculator.aimingSolutionForTarget()` returns vertical hold, windage,
  and the target-range trajectory point through both native and WASM engines.

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

[Unreleased]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.3...v1.0.0
[1.0.0-rc.5]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0-rc.4...v1.0.0-rc.5
[1.0.0-rc.4]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0-rc.2...v1.0.0-rc.4
[1.0.0-rc.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0-rc.1...v1.0.0-rc.2
[1.0.0-rc.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0-beta.2...v1.0.0-rc.1
[1.0.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0-beta.1...v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.3...v1.0.0-beta.1
[0.2.3]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.3...v0.2.0
[0.2.0-beta.3]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.2...v0.2.0-beta.3
[0.2.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.1...v0.2.0-beta.2
[0.2.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/releases/tag/v0.2.0-beta.1
