# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0-beta.1] - 2026-10-27

### Fixed
- **Android:** `libbclibc_ffi.so` could not be loaded on a device, so 2.0.0-alpha.1 does not work on Android. The hook
  linked libc++ dynamically (the `native_toolchain_c` default, `c++_shared`), but nothing puts `libc++_shared.so`
  into the APK: the build succeeded and `dlopen` failed at run time with `library "libc++_shared.so" not found`.
  libc++ is now linked statically (`c++_static`), together with libm (with a static libc++ nothing else pulls it in,
  and `pow` stayed unresolved), and the hook fails the build if the Android binary still references
  `libc++_shared.so`. CI now loads the library on an Android emulator, which is how this was found.
- `BcLibC.open()` no longer succeeds with an unusable library. With the `@Native` bindings of 2.0.0-alpha.1 the
  library is resolved lazily, so `open()` just created an object and a missing or unloadable `libbclibc_ffi` only
  failed later, at the first calculation, as an `ArgumentError` ("Couldn't resolve native function ...") -- which
  defeated startup checks such as `try { BcLibC.open(); } catch (...) { exit(1); }`. It now calls
  `BCLIBCFFI_get_version()` right away and throws a `StateError` that names the library.

### Added
- The build hook checks the library it just built, so a bad build fails the **build** instead of the app at startup:
  the file must exist, contain every `BCLIBCFFI_*` function the bindings call (catches a missing export, e.g. a
  symbol dropped by the Linux version script or not exported from the Windows DLL), and, when the target is the
  machine doing the build, actually load and answer `BCLIBCFFI_get_version()`. On that machine every symbol is
  looked up in the loaded library exactly as the runtime will do it; for cross-compiled targets (Android, iOS) the
  names are searched for in the binary, which is a weaker check.
- Android: the library is linked with `-Wl,-z,max-page-size=16384` (16 KB page alignment, required by Google Play for
  64-bit libraries), and CI checks every `LOAD` segment of the arm64-v8a and x86_64 libraries in the APK.
- `test/hook_test.dart` runs the hook through `testCodeBuildHook` (`package:code_assets`): it must emit exactly one
  bundled code asset, `package:bclibc/ffi/bclibc_bindings.g.dart`, whose file name matches the target OS
  (`libbclibc_ffi.so` / `.dylib`, `bclibc_ffi.dll`).
- Stricter CI: the built example is run on Linux, Windows and macOS (it must load the engine and solve a shot, and
  must fail fast once the library is removed from the bundle), `scripts/ci/missing-library-check.sh` does the same
  for a plain Dart executable, an Android emulator job loads the library on a device and an iOS job builds the
  example for a device (arm64) and runs it on a simulator (`example/integration_test`). The Android job also
  checks that the library needs no `libc++_shared.so`.
- The Flatpak workflow has a `bclibc_version` input: with a published version it builds the example against that
  release from pub.dev instead of the path dependency, which proves the offline build works from the package
  archive alone.

### Changed
- CI: a new push to a pull request cancels the run still going for its previous commit (runs on `main` and manual
  runs are never cancelled, `release.yml` needs them); the self-test in `scripts/ci/flutter-smoke.sh` has its own
  120 s limit (macOS has no `timeout`) and prints the app's output when it fails; the Flutter jobs have a time limit.

## [2.0.0-alpha.1] - 2026-10-27

This release merges `bclibc_flutter` into `bclibc`: one package now works on the Dart VM, in Flutter
(Android/iOS/Linux/macOS/Windows) and on the web (Dart web and Flutter web), with a single bclibc pin.

**Migrating from `bclibc_flutter`:** depend on `bclibc: ^2.0.0-alpha.1` instead and replace
`package:bclibc_flutter/...` imports with `package:bclibc/...` (`bclibc.dart` and `unit.dart` are unchanged).
No platform setup is needed: the native library is built by the package itself.

### Changed
- **BREAKING:** the native library is built by a build hook (`hook/build.dart`, `package:hooks` +
  `native_toolchain_c`) from the bundled `bclibc/` sources and loaded as a code asset. The FFI bindings
  (`lib/ffi/bclibc_bindings.g.dart`) are regenerated in `@Native` mode (`ffi-native` in `ffigen.yaml`), so
  `dart run`, `dart test`, `flutter run`, `flutter build` and `flutter test` resolve the library the same way,
  with no build step, no network access and no `package_config.json` lookup. Requires Dart 3.11+ and a C++
  toolchain on the build machine.
- **BREAKING:** `BcLibCFFIBindings` (a class wrapping a `DynamicLibrary`) is gone; the bindings are top-level
  `@Native` functions. `BcLibC.open()` is unchanged.
- `AsyncCalculator` (from `bclibc_flutter`) and the web binding (`BcLibCWeb`) now live in this package, selected
  by `dart.library.js_interop` in `bclibc.dart`. `BcLibCWeb.open()` uses the wasm module embedded in the package
  by default; `wasmUrl` is only for a differently-built or differently-hosted module.
- The wasm module is embedded as a base64 constant (`lib/ffi/bclibc_wasm.g.dart`, written by
  `scripts/embed_wasm.py` from `make build-wasm`) instead of a Flutter asset, so it needs no asset bundling or
  hosting and works the same in Dart web, Flutter web and `dart test -p chrome`.
- Repository layout: the package lives at the repository root (it was in `dart/`) and the bclibc submodule is
  `bclibc/` (it was `dart/bclibc`). A `.pubignore` keeps `.github/`, `scripts/`, `Makefile` and the submodule's
  tests out of the pub.dev archive.
- Dependencies: `hooks`, `code_assets`, `native_toolchain_c` and `web` added, `path` dropped (it only served the
  removed library loader).
- CI and release: every CI job now runs on the single package (`Analyze`, `Test`, `Test / web (Chrome)`,
  `Test / Flutter consumer (Linux)`, `pub.dev dry-run`). Tests are no longer re-run for a release tag:
  `release.yml` requires a successful `ci.yml` run on the tagged commit instead (`ci.yml` can be started
  manually with `workflow_dispatch`), checks `pubspec.yaml` and this changelog, and publishes only `bclibc`.
  `scripts/ci/prepare_release.py` and `make verify-bclibc` follow the new layout.

### Added
- Web support in this package: `BcLibCWeb` and a web `AsyncCalculator`, no Flutter SDK required.
- `scripts/ci/flutter-smoke.sh` and a CI job that run `flutter test` in a throwaway Flutter project depending
  on this package.
- `make web-test` (web tests in Chrome) and `make submodule`.

### Removed
- **BREAKING:** `dart run bclibc:build_native` (`bin/build_native.dart`) and the `BCLIBC_FFI_PATH` environment
  variable: the build hook replaces them.
- The `bclibc_flutter` package and its platform plugin code (CMake/Gradle/podspec): it is no longer built or
  released from this repository (the last published version is 1.0.1).
- The `flutter/bclibc` submodule and `sync-bclibc`: `bclibc/` is the single bclibc pin (`make verify-bclibc`
  now checks that pin, the embedded wasm module and this changelog).

## [1.0.1] - 2026-10-27

### Fixed
- The native library is found under `flutter test` on Flutter 3.47+: there `Isolate.resolvePackageUriSync` throws
  `UnsupportedError`, so the library placed by `dart run bclibc:build_native` was unreachable. As a last resort the
  loader now reads `.dart_tool/package_config.json` directly (local files only, no network). It runs after the
  executable-relative lookup, so compiled and bundled builds are unchanged.

## [1.0.0] - 2026-10-03

Stable release, covering the whole arc from 0.2.3 through 1.0.0-rc.5. Highlights below; full details are in
the beta/rc entries beneath this one.

### Changed
- `HitResult` now separates exact chronological `records`, physical `events`, and stable scheduled `samples`.
  `trajectory` remains as a deprecated alias for `records`.
- The native library is built from bclibc's exception-free core (every fallible call returns a result that the
  flat C ABI maps to a `BCLIBCFFI_*` error code): same Dart API, error codes and messages.
- Regenerated `lib/ffi/bclibc_bindings.g.dart` (`make ffigen`) for the interpolation functions of the C ABI,
  `BCLIBCFFI_hermite`, `BCLIBCFFI_interpolate_2pt`/`_3pt` and `BCLIBCFFI_interpolate_trajectory_data`.

### Added
- `BcIntegrationMethod.cashKarp`/`.dormandPrince`/`.tsitouras`: three adaptive RK45 integration methods, alongside
  the existing RK4.
- `Calculator.aimingSolutionForTarget()` returns vertical hold, windage, and the target-range trajectory point
  from the native zero-point solve.

### Chores
- Pin `bclibc` to `v2.0.0`

## [1.0.0-rc.5] - 2026-10-01


### Changed
- The native library is built from bclibc's exception-free core (every fallible call returns a result that the flat C
  ABI maps to a `BCLIBCFFI_*` error code): same Dart API, error codes and messages.
- Regenerated `lib/ffi/bclibc_bindings.g.dart` (`make ffigen`): it now also binds the interpolation functions of the
  C ABI, `BCLIBCFFI_hermite`, `BCLIBCFFI_interpolate_2pt`/`_3pt` and `BCLIBCFFI_interpolate_trajectory_data`.

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

- Pin `bclibc` to `v2.0.0-rc.1` — replaces the embedded RK45 methods'
  thread-local tolerance/stats API (shared by every engine on a thread using
  the same method) with stateful `BCLIBC_CashKarpIntegrator`/
  `BCLIBC_DormandPrinceIntegrator`/`BCLIBC_TsitourasIntegrator` classes.
  Internal to bclibc; no change to the Dart FFI surface, which only ever
  calls the plain `BCLIBCFFI_integrate*` functions, unaffected by this.

## [1.0.0-beta.2] - 2026-09-21


### Changed

- Pin `bclibc` to `v2.0.0-beta.8`, adding the adaptive Tsitouras 5(4)
  integration method.

### Added

- `BcIntegrationMethod.tsitouras` selects the Tsitouras 5(4) integrator.
- FFI test covering the Cash-Karp, Dormand-Prince and Tsitouras integrators
  against RK4.

## [1.0.0-beta.1] - 2026-09-17

### Changed

- Pin `bclibc` to `v2.0.0-beta.7`, adding experimental Cash-Karp and
  Dormand-Prince integration methods and the zero-point FFI result API.
- `HitResult` now separates exact chronological `records`, physical `events`,
  and stable scheduled `samples`. `trajectory` remains as a deprecated alias
  for `records`.

### Added

- `Calculator.aimingSolutionForTarget()` returns vertical hold, windage, and
  the target-range trajectory point from the native zero-point solve.

## [0.2.3] - 2026-09-15

### Changed

- **Breaking:** package renamed from `dart_bclibc` to `bclibc`. Update your
  `pubspec.yaml` dependency and every `package:dart_bclibc/...` import to
  `package:bclibc/...`.

### Migration

- `dependencies: { dart_bclibc: ^0.2.2 }` → `dependencies: { bclibc: ^0.2.3 }`
- `import 'package:dart_bclibc/bclibc.dart';` → `import 'package:bclibc/bclibc.dart';`
  (and likewise for every other `package:dart_bclibc/...` import).

## [0.2.2] - 2026-09-15

### Fixed
- `Distance.centimeter()` constructed a `Distance` with `Unit.inch` instead of
  `Unit.centimeter`, silently misinterpreting the given value as inches.

## [0.2.1] - 2026-09-14

### Added
- `BcIntegrationMethod.velocityVerlet`

### Changed
- Pin `bclibc` to `v1.1.8`

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

### Changed

- **Breaking:** split the package. `bclibc` is now pure Dart — no
  `package:flutter` dependency, installable from plain Dart (non-Flutter)
  projects. Everything Flutter-specific (native platform bundling for
  Android/iOS/Linux/macOS/Windows, Web/WebAssembly support, and
  `AsyncCalculator`, which needs a real web implementation) moved to the new
  [`bclibc_flutter`](https://pub.dev/packages/bclibc_flutter)
  package. `bclibc` itself now only exposes the synchronous
  `Calculator`/`BcLibC` (native FFI); wrap `Calculator` in your own
  `Isolate.run` for off-isolate execution in a plain Dart project.
- `dart run bclibc:build_native` now copies the built native library
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

- Flutter apps: depend on `bclibc_flutter` instead of `bclibc`
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
  - `package:bclibc/bclibc.dart` conditionally excludes the native-only
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
  `bclibc_bundled_libraries → PLUGIN_BUNDLED_LIBRARIES`, matching the behaviour
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
  invoked as `dart run bclibc:build_native` from a consuming project
  (as opposed to running it directly from within this repo, which is how it
  was tested for 0.1.0-beta.2). Switched to `Isolate.resolvePackageUri`,
  which goes through the actual `package_config.json` resolution and works
  regardless of pub-cache vs. path dependency vs. snapshot caching.

## [0.1.0-beta.2] - 2026-07-01

### Added
- `bin/build_native.dart` — `dart run bclibc:build_native` builds the
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

[Unreleased]: https://github.com/ballistics-lab/dart-bclibc/compare/v2.0.0-beta.1...HEAD
[2.0.0-beta.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v2.0.0-alpha.1...v2.0.0-beta.1
[2.0.0-alpha.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.1...v2.0.0-alpha.1
[1.0.1]: https://github.com/ballistics-lab/dart-bclibc/compare/v1.0.0...v1.0.1
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
