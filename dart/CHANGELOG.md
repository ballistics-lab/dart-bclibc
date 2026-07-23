# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0-beta.2] - 2026-07-23

### Added
- Update flutter package's umbrella

## [0.2.0-beta.1] - 2026-07-22

### Changed

- **Breaking:** split the package. `dart_bclibc` is now pure Dart — no
  `package:flutter` dependency, installable from plain Dart (non-Flutter)
  projects. Everything Flutter-specific (native platform bundling for
  Android/iOS/Linux/macOS/Windows, Web/WebAssembly support, and
  `AsyncCalculator`, which needs a real web implementation) moved to the new
  [`dart_bclibc_flutter`](https://pub.dev/packages/dart_bclibc_flutter)
  package. `dart_bclibc` itself now only exposes the synchronous
  `Calculator`/`BcLibC` (native FFI); wrap `Calculator` in your own
  `Isolate.run` for off-isolate execution in a plain Dart project.
- `dart run dart_bclibc:build_native` now copies the built native library
  into the package's own `lib/native/<platform>/` directory (resolved via a
  `package:` URI at load time) instead of a `build/bclibc/` directory
  relative to the caller's working directory — more robust across different
  invocation locations, and independent of cwd.
- `BcLibC.open()`'s native-library loader was rewritten with a clearer,
  more robust multi-strategy resolution order (env var → `package:` URI →
  platform-specific fallback → executable-relative), and now has a real iOS
  code path — previously `_openLibrary()` threw `UnsupportedError`
  unconditionally on iOS.

### Migration

- Flutter apps: depend on `dart_bclibc_flutter` instead of `dart_bclibc`
  directly (it re-exports everything from this package, plus
  `AsyncCalculator` and web support).
- Plain Dart apps: no changes needed beyond dropping any direct use of
  `AsyncCalculator`.

## [0.1.2-beta.2] - 2026-07-22

### Added
- `web:` entry (`pluginClass: BclibcWebPlugin`) in `pubspec.yaml`'s
  `flutter.plugin.platforms`, backed by a new `lib/src/bclibc_web_plugin.dart`.
  The registrant is a no-op — `AsyncCalculator` never goes through platform
  channels on web, it calls the wasm engine directly via `dart:js_interop` —
  but Flutter's tooling requires a real `pluginClass` for any platform listed
  under `flutter.plugin.platforms`, and pub.dev only lists a plugin's
  supported platforms from that map. Without this entry, Web support existed
  in practice but wasn't shown on pub.dev.
- CI: `release.yml` now runs the web/Chrome test suite (mirroring `ci.yml`'s
  `test-web` job) as a required check before a release can be prepared.

### Changed
- New `flutter_web_plugins` dependency (Flutter SDK package), required for
  the `Registrar` type the no-op web registrant's `registerWith` accepts.

## [0.1.2-beta.1] - 2026-07-22

### Added
- `AsyncCalculator`: `Future`-based counterpart to `Calculator` with the same
  three methods (`barrelElevationForTarget`, `setWeaponZero`, `fire`). On
  native, each call runs on a fresh isolate via `Isolate.run` so heavy
  trajectory integration doesn't block the caller's isolate (e.g. the UI
  isolate in a Flutter app). On web it awaits the (cached) wasm engine load
  once, then calls straight through — no isolate involved.
- Web/wasm support: `bclibc`'s C ABI (`bclibc_ffi.h`) can now be compiled to
  WebAssembly (see `bclibc/build_wasm.sh`) and consumed via `dart:js_interop`
  through `BcLibCWeb` (`lib/ffi/bclibc_ffi_web.dart`) — no Embind, no
  third-party FFI-on-web shim; it talks to the same flat `BCLIBCFFI_*`
  exports the native `dart:ffi` binding uses. Struct field offsets aren't
  hardcoded on the Dart side: `BCLIBCFFI_get_layout()` computes them via
  `offsetof()`/`sizeof()` in whichever compiler built the wasm module, so the
  binding can't silently drift from the C struct layout.
  - The compiled wasm artifact (`assets/wasm/bclibc_ffi.js` + `.wasm`) is
    now bundled with the package via `flutter.assets` in `pubspec.yaml`, so
    `flutter build web` picks it up automatically.
  - `package:dart_bclibc/bclibc.dart` conditionally excludes the native-only
    `Calculator` / `BcLibC` / generated `dart:ffi` bindings when compiling
    for web (`if (dart.library.js_interop)`), so importing the package
    barrel compiles cleanly on both platforms — web consumers use
    `AsyncCalculator`.
  - New `test/web/` suite (`dart test -p chrome`) verifies numeric parity
    between the wasm and native engines.

### Changed
- Internals reorganized so native and web share one conversion-logic code
  path (`lib/src/calculator_core.dart`, `lib/ffi/bclibc_types.dart`,
  `BcEngine` interface) instead of duplicating it — no public API changes on
  native; `Calculator`'s constructor and methods are unchanged.
- Pin `bclibc` to `v1.1.6` — adds `build_wasm.sh` and `BCLIBCFFI_get_layout()`
  upstream, which this release's web/wasm support builds on.

## [0.1.1] - 2026-07-21

### Changed
- Pin `bclibc` to `v1.1.5` 

## [0.1.0] - 2026-07-03

First stable release. No functional changes since 0.1.0-beta.5 — the API,
build system, and platform support are unchanged; this release marks the
package as stable for pub.dev.

## [0.1.0-beta.5] - 2026-07-02

### Fixed
- `linux/CMakeLists.txt`: beta.4 used `install(FILES "$<TARGET_LINKER_FILE:bclibc_ffi>")`,
  which copies the `.so` namelink itself (not its target) in cmake < 3.21 — producing a
  broken symlink in the Flutter bundle (`libbclibc_ffi.so → libbclibc_ffi.so.0`) with no
  real library present, causing `DynamicLibrary.open()` to fail at runtime. Fixed by
  switching to `install(TARGETS bclibc_ffi LIBRARY DESTINATION lib)`, which installs the
  real versioned file together with its soname and namelink symlinks into the same
  directory — matching the standard Linux shared library layout and keeping the symlink
  chain valid.
- `windows/CMakeLists.txt`: beta.4 added a redundant `install(FILES bclibc_ffi.dll
  DESTINATION .)` that doubled up with the standard `PLUGIN_BUNDLED_LIBRARIES` install
  loop already present in every Flutter app's `windows/CMakeLists.txt`. Removed the
  explicit `install()` call; the DLL is now delivered exclusively via
  `dart_bclibc_bundled_libraries → PLUGIN_BUNDLED_LIBRARIES`, matching the behaviour
  of the previous `bclibc_ffi` local package.

## [0.1.0-beta.4] - 2026-07-02

### Changed
- `linux/CMakeLists.txt` and `windows/CMakeLists.txt` now register their own
  CMake `install()` rules for `bclibc_ffi`, so consuming Flutter apps no longer
  need to add manual `install(TARGETS bclibc_ffi …)` blocks to their platform
  `CMakeLists.txt`. On Windows, `add_dependencies(flutter_assemble bclibc_ffi)`
  is also registered automatically, preserving the correct build order in
  Visual Studio. Android is unaffected — the Gradle/AGP native build collects
  shared library targets from the CMake project without `install()`.

## [0.1.0-beta.3] - 2026-07-01

### Fixed
- `bin/build_native.dart` resolved its own package root via `Platform.script`,
  which points at a cached kernel snapshot in the *caller's*
  `.dart_tool/pub/bin/` — not this file's real location in pub-cache — when
  invoked as `dart run dart_bclibc:build_native` from a consuming project
  (as opposed to running it directly from within this repo, which is how it
  was tested for 0.1.0-beta.2). Switched to `Isolate.resolvePackageUri`,
  which goes through the actual `package_config.json` resolution and works
  regardless of pub-cache vs. path dependency vs. snapshot caching.

## [0.1.0-beta.2] - 2026-07-01

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
  `libbclibc_ffi.dylib` — compiled from `bclibc/` (v1.1.5, LGPL-3.0)
- CMake build strategy (Linux/Windows/Android):
  1. submodule present → `add_subdirectory` (pub.dev; run `git submodule update --init` before publishing)
  2. pre-installed library found → use it (Flatpak `/app/lib`)
  3. fallback → `FetchContent` from GitHub (git dep via `dart pub get`)

[Unreleased]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.2...HEAD
[0.2.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.2.0-beta.1...v0.2.0-beta.2
[0.2.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.2-beta.2...v0.2.0-beta.1
[0.1.2-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.2-beta.1...v0.1.2-beta.2
[0.1.2-beta.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.1...v0.1.2-beta.1
[0.1.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.5...v0.1.0
[0.1.0-beta.5]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.4...v0.1.0-beta.5
[0.1.0-beta.4]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.3...v0.1.0-beta.4
[0.1.0-beta.3]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.2...v0.1.0-beta.3
[0.1.0-beta.2]: https://github.com/ballistics-lab/dart-bclibc/compare/v0.1.0-beta.1...v0.1.0-beta.2
[0.1.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/releases/tag/v0.1.0-beta.1
