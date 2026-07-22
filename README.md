# dart_bclibc

Dart FFI bindings for the [bclibc](https://github.com/ballistics-lab/bclibc) ballistics engine.

[![Made in Ukraine]][SWUBadge]

[![License]](LICENSE)
[![Pub Version]][pub package]
[![powered by bclibc]][bclibc repo]

![Linux] ![Windows] ![Android] ![iOS] ![macOS]

[![CI](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml/badge.svg)](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml)

A thin, zero-copy Dart wrapper around `libbclibc_ffi` — a high-performance 3-DOF + spin drift ballistic solver engine with RK4/Euler integration. Ships with the [bclibc](https://github.com/ballistics-lab/bclibc) C++ source as a git submodule; no pre-built binaries required.

---

## Table of Contents

- [dart\_bclibc](#dart_bclibc)
  - [Table of Contents](#table-of-contents)
  - [Quick start](#quick-start)
  - [API](#api)
    - [Input types](#input-types)
    - [Result types](#result-types)
    - [`BcLibC` methods](#bclibc-methods)
    - [Enums](#enums)
  - [Async API](#async-api)
  - [Web / WebAssembly](#web--webassembly)
  - [Atmosphere and Coriolis](#atmosphere-and-coriolis)
  - [Unit system](#unit-system)
  - [Building](#building)
    - [Prerequisites](#prerequisites)
    - [Clone](#clone)
    - [Build native library](#build-native-library)
      - [Consuming apps: `flutter test` / `dart test`](#consuming-apps-flutter-test--dart-test)
    - [Regenerate FFI bindings](#regenerate-ffi-bindings)
    - [Run tests](#run-tests)
  - [Native library](#native-library)
  - [Dependencies](#dependencies)
  - [License](#license)

---

## Quick start

```dart
import 'package:dart_bclibc/bclibc.dart';

final bc = BcLibC.open(); // loads the native library once

final shot = BcShot(
  bc: 0.295,
  weightGrain: 168.0,
  diameterInch: 0.308,
  lengthInch: 1.22,
  muzzleVelocityFps: 2750.0,
  sightHeightFt: 0.1148,
  twistInch: 10.0,
  tempC: 15.0,
  pressureHpa: 1013.25,
  altitudeFt: 0.0,
  dragTable: [BcDragPoint(0.0, 0.0), /* … Mach / CD pairs … */],
  lookAngleRad: 0.0,
  barrelElevationRad: 0.0,
);

final hit = bc.integrateShot(
  shot,
  BcTrajectoryRequest(rangeLimitFt: 3000.0, rangeStepFt: 100.0),
);

for (final pt in hit.trajectory) {
  print('${pt.distanceFt} ft  ${pt.velocityFps} fps  ${pt.heightFt} ft');
}
```

---

## API

### Input types

| Dart type             | Description                                                                                                                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BcShot`              | Preferred shot input (natural units). All physics conversion — atmosphere density, Coriolis trig, PCHIP drag curve, cant — is performed inside C++ via `BCLIBCFFI_Shot::to_shot_props()`. |
| `BcShotProps`         | Legacy shot input (pre-computed `BcAtmosphere`/`BcCoriolis` structs).                                                                                                                     |
| `BcTrajectoryRequest` | Step size, range limit, and `BCLIBCFFI_TrajFlag` filter bitmask.                                                                                                                          |
| `BcConfig`            | Solver knobs (step multiplier, accuracy, gravity constant, etc.).                                                                                                                         |
| `BcDragPoint`         | One Mach / CD entry for the drag table.                                                                                                                                                   |
| `BcWind`              | One wind segment (velocity, direction, distance bounds).                                                                                                                                  |

### Result types

| Dart type          | Description                                           |
| ------------------ | ----------------------------------------------------- |
| `BcTrajectoryData` | One filtered trajectory record.                       |
| `BcHitResult`      | Full trajectory list + `BCLIBCFFI_TerminationReason`. |
| `BcInterception`   | Single interpolated point from `integrateAtShot`.     |
| `BcMaxRangeResult` | Max range (ft) + angle (rad) from `findMaxRangeShot`. |

### `BcLibC` methods

| Method                                       | Description                                     |
| -------------------------------------------- | ----------------------------------------------- |
| `BcLibC.open()`                              | Load the native library (call once at startup). |
| `integrateShot(BcShot, BcTrajectoryRequest)` | Full filtered trajectory.                       |
| `integrateAtShot(BcShot, key, value)`        | Single interpolated point at a trajectory key.  |
| `findZeroAngleShot(BcShot, distanceFt)`      | Barrel elevation to zero at distance.           |
| `findApexShot(BcShot)`                       | Highest point of the trajectory arc.            |
| `findMaxRangeShot(BcShot)`                   | Maximum range and corresponding angle.          |
| `getCorrection(distanceFt, offsetFt)`        | Angular correction (rad) for a linear offset.   |
| `calculateEnergy(grains, fps)`               | Kinetic energy (ft-lb).                         |
| `calculateOgw(grains, fps)`                  | Optimal Game Weight.                            |

Legacy `BcShotProps`-based overloads (`findApex`, `findMaxRange`, etc.) are retained for backwards compatibility.

### Enums

| Dart enum             | Description                                                                          |
| --------------------- | ------------------------------------------------------------------------------------ |
| `BCLIBCFFI_TrajFlag`  | Trajectory filter flags (`BCLIBCFFI_TRAJ_FLAG_RANGE`, `BCLIBCFFI_TRAJ_FLAG_APEX`, …) |
| `BcTerminationReason` | Why integration stopped (`BcHitResult.reason`).                                      |
| `BcBaseTrajInterpKey` | Key field selector for `integrateAtShot` (`.posX`, `.time`, `.mach`, …).             |
| `BcIntegrationMethod` | `BcIntegrationMethod.rk4` (default) or `.euler` (`BcShot.method`).                   |

`BcTerminationReason`, `BcBaseTrajInterpKey`, and `BcIntegrationMethod` (from
`lib/ffi/bclibc_types.dart`) are platform-agnostic — the same types work with
both `BcLibC` (native) and `BcLibCWeb` (web). They replace the raw
ffigen-generated `BCLIBCFFI_*` enum classes in the public API; those still
exist in `bclibc_bindings.g.dart` but are native-internal implementation
detail now.

---

## Async API

`AsyncCalculator` mirrors `Calculator`'s three methods
(`barrelElevationForTarget`, `setWeaponZero`, `fire`) but returns `Future`s,
and works on **both native and web**:

```dart
import 'package:dart_bclibc/bclibc.dart';

final calc = AsyncCalculator();
final result = await calc.fire(
  shot: shot,
  trajectoryRange: Distance.meter(1000),
);
```

- On native, each call runs on a fresh isolate via `Isolate.run`, so heavy
  trajectory integration doesn't block the caller's isolate (e.g. the UI
  isolate in a Flutter app).
- On web, the wasm engine is loaded once (cached) and every call after that
  runs synchronously through it — there's no isolate to offload to on web,
  and once the module is loaded, wasm calls are plain synchronous JS calls.

`Calculator` itself (the synchronous class) stays native-only — `dart:ffi`
doesn't exist on web, so there's no web equivalent of it. Web consumers use
`AsyncCalculator`.

---

## Web / WebAssembly

`bclibc`'s C ABI compiles to WebAssembly via `bclibc/build_wasm.sh`
(Emscripten), and is consumed on web through `BcLibCWeb`
(`lib/ffi/bclibc_ffi_web.dart`) using `dart:js_interop` directly against the
same flat `BCLIBCFFI_*` exports the native binding uses — no Embind, no
third-party FFI-on-web shim. Struct field offsets are never hardcoded on the
Dart side: `BCLIBCFFI_get_layout()` computes them via `offsetof()`/`sizeof()`
in whichever compiler built the wasm module, so the binding can't silently
drift from the C struct layout if it changes.

The compiled artifact (`assets/wasm/bclibc_ffi.js` + `.wasm`) ships with the
package via `flutter.assets` in `pubspec.yaml` — `flutter build web` picks
it up automatically, no extra setup needed in the consuming app.

```dart
import 'package:dart_bclibc/bclibc.dart';

// Works unmodified on web — AsyncCalculator picks the wasm engine
// automatically when compiled for web.
final calc = AsyncCalculator();
final elev = await calc.barrelElevationForTarget(shot, Distance.meter(500));
```

`package:dart_bclibc/bclibc.dart` conditionally excludes the native-only
`Calculator` / `BcLibC` / generated `dart:ffi` bindings when compiling for
web, so importing the package barrel compiles cleanly on both platforms.

To rebuild the wasm artifact from source (only needed if you're modifying
`bclibc` itself):

```bash
bclibc/build_wasm.sh   # self-installs a pinned Emscripten SDK on first run
cp bclibc/build/web/bclibc_ffi.{js,wasm} assets/wasm/
```

---

## Atmosphere and Coriolis

When using `BcShot`:

- Pass `pressureHpa: 0` for vacuum (zero drag).
- Pass `latitudeDeg: double.nan` to disable Coriolis (default `BcShot` value).
- Pass `azimuthDeg: double.nan` for flat-fire drift only.

---

## Unit system

`lib/unit.dart` provides typed unit wrappers with an `in_()` / `toDouble()` API:

```dart
import 'package:dart_bclibc/unit.dart';

final t = Temperature.celsius(15.0);
print(t.in_(TemperatureUnit.fahrenheit)); // 59.0

final d = Distance.meters(100.0);
print(d.in_(DistanceUnit.feet));          // 328.084...
```

Available types: `Distance`, `Velocity`, `Temperature`, `Pressure`, `Angular`, `Weight`, `Energy`.

---

## Building

### Prerequisites

- Dart SDK ≥ 3.11.4 (or Flutter ≥ 3.3.0)
- CMake ≥ 3.13
- C++17 compiler (GCC / Clang on Linux/macOS, MSVC 2022 on Windows)
- LLVM/Clang dev headers (only for regenerating FFI bindings)

### Clone

```bash
git clone --recurse-submodules https://github.com/ballistics-lab/dart-bclibc.git
cd dart-bclibc
```

If you cloned without `--recurse-submodules`:

```bash
git submodule update --init
```

### Build native library

```bash
make build
```

Or manually:

```bash
cmake -S bclibc -B build/bclibc -DCMAKE_BUILD_TYPE=Release
cmake --build build/bclibc --parallel
```

> For Flutter apps the native library is built and bundled automatically by `flutter build`.
> No changes to the app's platform `CMakeLists.txt` are required.
> On Linux the plugin registers `install(TARGETS bclibc_ffi LIBRARY)` rules that produce
> the standard versioned-file + soname + namelink layout in the bundle.
> On Windows the DLL is declared via `PLUGIN_BUNDLED_LIBRARIES` and installed by the app's
> existing loop; `add_dependencies(flutter_assemble bclibc_ffi)` ensures correct build order.
> Android is handled by Gradle/AGP without any `install()` rules.

#### Consuming apps: `flutter test` / `dart test`

`flutter build`/`flutter run` bundle the native library automatically, but
`flutter test`/`dart test` never run a platform build, so apps that depend on
`dart_bclibc` need to build it explicitly before testing:

```bash
dart run dart_bclibc:build_native
```

This builds `libbclibc_ffi` into `build/bclibc/` relative to your project's
working directory — one of the paths `BcLibC.open()` checks automatically.
Wire it into your test target, e.g. in a `Makefile`:

```makefile
test: build-bclibc
	flutter test

build-bclibc:
	dart run dart_bclibc:build_native
```

### Regenerate FFI bindings

```bash
# Install LLVM first:
#   Linux:   sudo apt install libclang-dev clang
#   macOS:   brew install llvm
#   Windows: winget install LLVM

make ffigen
```

The generated file is `lib/ffi/bclibc_bindings.g.dart`.

### Run tests

```bash
make test
```

---

## Native library

| Platform | Library name          |
| -------- | --------------------- |
| Linux    | `libbclibc_ffi.so`    |
| Android  | `libbclibc_ffi.so`    |
| macOS    | `libbclibc_ffi.dylib` |
| iOS      | `libbclibc_ffi.dylib` |
| Windows  | `bclibc_ffi.dll`      |

During development the path can be overridden via the `BCLIBC_FFI_PATH` environment variable.

---

## Dependencies

| Dependency                                                                      | Role                                                                                         |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| [bclibc](https://github.com/ballistics-lab/bclibc) v1.1.6                       | C++ ballistic solver engine (3-DOF + spin drift, RK4) — LGPL-3.0, bundled as a git submodule |
| [ffi](https://pub.dev/packages/ffi)                                             | Dart ↔ C FFI bindings                                                                        |
| [plugin_platform_interface](https://pub.dev/packages/plugin_platform_interface) | Flutter plugin platform interface                                                            |
| [web](https://pub.dev/packages/web)                                             | `dart:js_interop`-based DOM bindings, used by `BcLibCWeb` to load the wasm module            |

---

## License

Copyright (C) 2026 Yaroshenko Dmytro (o-murphy)

This library is free software: you can redistribute it and/or modify it under the terms of the **GNU Lesser General Public License v3.0** as published by the Free Software Foundation.

See [LICENSE](LICENSE) for the full text. See [CHANGELOG](CHANGELOG.md) for release history.

> [!NOTE]
> `bclibc` (the ballistic solver engine, located in `bclibc/`) is licensed separately under the **GNU Lesser General Public License v3.0**. See [`bclibc/LICENSE`](bclibc/LICENSE).

> [!WARNING]
> **Risk notice.** This package performs approximate simulations of complex physical processes. Calculation results must not be considered as completely or reliably reflecting actual projectile behaviour. Results may be used for educational purposes only and must not be relied upon in any context where an incorrect calculation could cause financial harm or put a human life at risk.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


<!-- REUSABLE LINKS -->


[Made in Ukraine]: https://img.shields.io/badge/made_in-Ukraine-ffd700.svg?labelColor=0057b7&style=flat-square
[SWUBadge]: https://stand-with-ukraine.pp.ua

[License]: https://img.shields.io/badge/License-LGPL%20v3-blue.svg

[Pub Version]: https://img.shields.io/pub/v/dart_bclibc?logo=dart&cacheSeconds=0
[pub package]: https://pub.dev/packages/dart_bclibc

[Linux]: https://img.shields.io/badge/Linux-x86__64%20%7C%20arm64-grey?logo=linux&logoColor=black&labelColor=FCC624
[Windows]: https://img.shields.io/badge/x86__64-grey?logo=windows&logoColor=black&label=Windows&labelColor=0078D4
[Android]: https://img.shields.io/badge/Android-arm64%20%7C%20armv7%20%7C%20x86__64-grey?logo=android&logoColor=white&labelColor=3DDC84
[iOS]: https://img.shields.io/badge/iOS-arm64-grey?logo=apple&logoColor=white&labelColor=000000
[macOS]: https://img.shields.io/badge/macOS-arm64%20%7C%20x86__64-grey?logo=apple&logoColor=white&labelColor=000000

[bclibc repo]: https://github.com/ballistics-lab/bclibc
[powered by bclibc]:
https://img.shields.io/badge/ballistics--lab%20%7C%20bclibc-0d1228?logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI%2FPgo8IURPQ1RZUEUgc3ZnIFBVQkxJQyAiLS8vVzNDLy9EVEQgU1ZHIDIwMDEwOTA0Ly9FTiIgImh0dHA6Ly93d3cudzMub3JnL1RSLzIwMDEvUkVDLVNWRy0yMDAxMDkwNC9EVEQvc3ZnMTAuZHRkIj4KPHN2ZyB2ZXJzaW9uPSIxLjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEwMjQuMDAwMDAwcHQiIGhlaWdodD0iMTAyNC4wMDAwMDBwdCIgdmlld0JveD0iMCAwIDEwMjQuMDAwMDAwIDEwMjQuMDAwMDAwIiBwcmVzZXJ2ZUFzcGVjdFJhdGlvPSJ4TWlkWU1pZCBtZWV0Ij4KCTxjaXJjbGUgY3g9IjUxMiIgY3k9IjUxMiIgcj0iNTEyIiBmaWxsPSIjMGQxMjI4IiAvPgoJPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTEwMCwxMTI0KSBzY2FsZSgwLjEyMDAwMCwtMC4xMjAwMDApIiBmaWxsPSIjRkZGRkZGIiBzdHJva2U9Im5vbmUiPgoJCTxwYXRoIGQ9Ik01MDU1IDgwNzEgYy0xNjcgLTMzMyAtMjczIC03NjggLTI5MiAtMTE5OCBsLTYgLTE0MyAzNDYgMCAzNDcgMCAwCjYzIGMwIDI3NSAtODAgNzMxIC0xNzUgMTAwNyAtMzkgMTEyIC0xNDUgMzQzIC0xNjMgMzU0IC03IDQgLTI5IC0yOCAtNTcgLTgzegptLTE1IC0yODkgYy00NiAtMjI1IC05MCAtNjYzIC05MCAtODk0IDAgLTEwNCAtMiAtMTA4IC02MSAtMTA4IGwtNDkgMCAwIDc4CmMxIDE1OSA0OCA0ODIgMTAxIDY5MCAzNCAxMzQgMTE5IDM5NiAxMjUgMzg5IDMgLTMgLTkgLTcyIC0yNiAtMTU1eiIgLz4KCQk8cGF0aCBkPSJNNDcxMCA2NDA2IGwwIC0yNDQgMjMgLTYgYzEyIC0zIDMyIC02IDQ1IC02IGwyMiAwIDAgMjI1IDAgMjI1IDY1IDAKNjUgMCAwIC0yMjUgMCAtMjI1IDI4MyAyIDI4MiAzIDMgMjQ4IDIgMjQ3IC0zOTUgMCAtMzk1IDAgMCAtMjQ0eiIgLz4KCQk8cGF0aCBkPSJNNDQyNCA2MTExIGMtMTggLTUgLTQ4IC0xOCAtNjggLTMwIC0xMzcgLTg1IC0xMjAgLTMwMCAyOSAtMzcwIGw0NgotMjEgLTMgLTUzMyAtMyAtNTMyIC0yMyAtNTggYy0xOCAtNDUgLTU0NSAtODUwIC04NzkgLTEzNDMgLTc2IC0xMTMgLTExMgotMjkxIC04MyAtNDE1IDQxIC0xNzcgMTY5IC0zMTIgMzQwIC0zNTkgNTkgLTE3IDI1OTMgLTE1IDI2NTUgMiAxMTQgMzAgMjMzCjEyMiAyODcgMjI0IDc2IDE0MiA3NyAzNDMgMyA0ODYgLTI4IDU0IC0xMzMgMjEzIC01NzMgODc1IC0xNzYgMjY2IC0zMzEgNTA5Ci0zNDQgNTQwIC0yMyA1OCAtMjMgNjAgLTI2IDU4OCBsLTMgNTMwIDQ1IDE4IGM1MiAyMiAxMDEgODAgMTE3IDE0MSAyNCA5MAotMjMgMTk2IC0xMDYgMjM2IC01NCAyNiAtMTk5IDM1IC0yMDEgMTMgLTEgLTcgLTIgLTE3IC0zIC0yMiAwIC01IC04OCAtNwotMjA4IC0zIC0xNTQgNCAtMjA0IDIgLTE5OSAtNiA0IC03IDE1IC0xMiAyNiAtMTIgMTAgMCA5MiAtMTMgMTgxIC0yOSA5MCAtMTYKMjA2IC0zMyAyNTggLTM3IDEwOSAtNyAxNDEgLTI3IDE0MSAtODYgLTEgLTYwIC00OCAtOTggLTEyNSAtOTggbC00NiAwIDMKLTU5MiAzIC01OTMgMjUgLTcwIGMxOCAtNTIgODAgLTE1NCAyNDEgLTM5NSA0NzYgLTcxNCA2ODkgLTEwNDMgNzEwIC0xMDk3IDE2Ci00NCAyMiAtNzkgMjIgLTE0MyAwIC0xNzQgLTgxIC0yOTMgLTIzNyAtMzQ3IC00OCAtMTcgLTEyNSAtMTggLTEzMzEgLTE4CmwtMTI4MCAwIC02NSAzMSBjLTc5IDM4IC0xMzEgODkgLTE2OCAxNjMgLTI1IDUxIC0yNyA2NiAtMjcgMTcxIDAgOTggMyAxMjIKMjIgMTYzIDEzIDI3IDExNiAxODkgMjI5IDM2MCAxMTQgMTcyIDMwOCA0NjQgNDMyIDY1MCAxMjMgMTg1IDIzNiAzNjMgMjUyCjM5NSA1NCAxMTEgNTUgMTIwIDU1IDc0MiBsMCA1NzUgLTUwIDYgYy0yNyAzIC01OCA5IC02OCAxNCAtMjcgMTEgLTQ5IDYyIC00Mgo5NCAxMCA0OCA0MyA2OSAxMTAgNzMgbDYwIDMgMCA2MCAwIDYwIC01MCAyIGMtMjcgMSAtNjQgLTIgLTgxIC02eiIgLz4KCQk8cGF0aCBkPSJNNDcwMCA1MzY5IGMwIC00MjggLTQgLTcwNyAtMTEgLTc1MiAtMjMgLTE1NyAtNTggLTIzMCAtMjYzIC01NDAKLTg0IC0xMjggLTE5NSAtMjk3IC0yNDggLTM3NyAtNTIgLTgwIC0xNjYgLTI1MyAtMjUzIC0zODUgLTg3IC0xMzIgLTE2OSAtMjYwCi0xODIgLTI4NCAtNDMgLTgyIC0yNiAtMTk3IDM5IC0yNTggNTkgLTU2IC03IC01MyAxMzI3IC01MyBsMTIyOSAwIDUyIDI4IGM5OAo1MSAxMzIgMTc2IDc3IDI4MiAtMjMgNDUgLTI2MSA0MTAgLTYzMyA5NzUgLTIzOCAzNjEgLTI1OCAzOTUgLTMwMiA1NDQgLTE0CjQ5IC0xNyAxMzkgLTIyIDcxNiBsLTUgNjYwIC0xMTUgMTcgYy02MyAxMCAtMTg1IDI5IC0yNzEgNDMgLTIxNyAzNSAtMTk5IDM5Ci0xOTkgLTQ4IDAgLTQxIC00IC0xNTQgLTEwIC0yNTMgLTUgLTk4IC0xNyAtMzEyIC0yNSAtNDc0IC05IC0xNjIgLTIwIC0zNDcKLTI1IC00MTAgLTUgLTYzIC0xMCAtMTQ1IC0xMCAtMTgyIDAgLTM4IC00IC02OCAtOCAtNjggLTggMCAtMjggNTcwIC0zOSAxMTU3CmwtNiAzMzEgLTMwIDYgYy0xNiAzIC0zOCA2IC00OCA2IC0xOCAwIC0xOSAtMjIgLTE5IC02ODF6IG0xMDMyIC0xNDI2IGM5IC0xMAo3NCAtMTA2IDE0NCAtMjE1IDcxIC0xMDggMjAzIC0zMDkgMjk0IC00NDcgMjEwIC0zMTggMjAyIC0zMDUgMjA0IC0zNTMgMSAtMzIKLTUgLTQ1IC0yNyAtNjQgbC0yOCAtMjQgLTEyMTUgMCAtMTIxNSAwIC0yNCAyNSBjLTE5IDE4IC0yNSAzNSAtMjUgNjggMCA0MQoxNyA2OSAyMDYgMzU4IDExNCAxNzMgMjU5IDM5NCAzMjMgNDkxIGwxMTYgMTc4IDYxNiAwIGM1NzQgMCA2MTcgLTEgNjMxIC0xN3oiIC8%2BCgk8L2c%2BCjwvc3ZnPgo%3D&label=powered%20by