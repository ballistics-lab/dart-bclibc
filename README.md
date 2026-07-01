# dart_bclibc

Dart FFI bindings for the [bclibc](https://github.com/ballistics-lab/bclibc) ballistics engine.

[![Made in Ukraine]][SWUBadge]

[![License]](LICENSE)
[![Pub Version]][pub package]
[![bclibc version]](bclibc)

![Linux] ![Windows] ![Android] ![iOS] ![macOS]

[![CI](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml/badge.svg)](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml)

> [!WARNING]
> **Beta software.** Expect breaking changes and rough edges.

A thin, zero-copy Dart wrapper around `libbclibc_ffi` — a high-performance 3-DOF + spin drift ballistic solver engine with RK4/Euler integration. Ships with the [bclibc](https://github.com/ballistics-lab/bclibc) C++ source as a git submodule; no pre-built binaries required.

---

## Table of Contents

- [Quick start](#quick-start)
- [API](#api)
  - [Input types](#input-types)
  - [Result types](#result-types)
  - [BcLibC methods](#bclibc-methods)
  - [Enums](#enums)
- [Atmosphere and Coriolis](#atmosphere-and-coriolis)
- [Unit system](#unit-system)
- [Building](#building)
  - [Prerequisites](#prerequisites)
  - [Clone](#clone)
  - [Build native library](#build-native-library)
    - [Consuming apps: flutter test / dart test](#consuming-apps-flutter-test--dart-test)
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

| Dart type | Description |
|---|---|
| `BcShot` | Preferred shot input (natural units). All physics conversion — atmosphere density, Coriolis trig, PCHIP drag curve, cant — is performed inside C++ via `BCLIBCFFI_Shot::to_shot_props()`. |
| `BcShotProps` | Legacy shot input (pre-computed `BcAtmosphere`/`BcCoriolis` structs). |
| `BcTrajectoryRequest` | Step size, range limit, and `BCLIBCFFI_TrajFlag` filter bitmask. |
| `BcConfig` | Solver knobs (step multiplier, accuracy, gravity constant, etc.). |
| `BcDragPoint` | One Mach / CD entry for the drag table. |
| `BcWind` | One wind segment (velocity, direction, distance bounds). |

### Result types

| Dart type | Description |
|---|---|
| `BcTrajectoryData` | One filtered trajectory record. |
| `BcHitResult` | Full trajectory list + `BCLIBCFFI_TerminationReason`. |
| `BcInterception` | Single interpolated point from `integrateAtShot`. |
| `BcMaxRangeResult` | Max range (ft) + angle (rad) from `findMaxRangeShot`. |

### `BcLibC` methods

| Method | Description |
|---|---|
| `BcLibC.open()` | Load the native library (call once at startup). |
| `integrateShot(BcShot, BcTrajectoryRequest)` | Full filtered trajectory. |
| `integrateAtShot(BcShot, key, value)` | Single interpolated point at a trajectory key. |
| `findZeroAngleShot(BcShot, distanceFt)` | Barrel elevation to zero at distance. |
| `findApexShot(BcShot)` | Highest point of the trajectory arc. |
| `findMaxRangeShot(BcShot)` | Maximum range and corresponding angle. |
| `getCorrection(distanceFt, offsetFt)` | Angular correction (rad) for a linear offset. |
| `calculateEnergy(grains, fps)` | Kinetic energy (ft-lb). |
| `calculateOgw(grains, fps)` | Optimal Game Weight. |

Legacy `BcShotProps`-based overloads (`findApex`, `findMaxRange`, etc.) are retained for backwards compatibility.

### Enums

| Dart enum | Description |
|---|---|
| `BCLIBCFFI_TrajFlag` | Trajectory filter flags (`BCLIBCFFI_TRAJ_FLAG_RANGE`, `BCLIBCFFI_TRAJ_FLAG_APEX`, …) |
| `BCLIBCFFI_TerminationReason` | Why integration stopped. |
| `BCLIBCFFI_BaseTrajInterpKey` | Key field selector for `integrateAtShot`. |
| `BCLIBCFFI_IntegrationMethod` | `BCLIBCFFI_INTEGRATION_RK4` (default) or `BCLIBCFFI_INTEGRATION_EULER`. |

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

| Platform | Library name |
|---|---|
| Linux | `libbclibc_ffi.so` |
| Android | `libbclibc_ffi.so` |
| macOS | `libbclibc_ffi.dylib` |
| iOS | `libbclibc_ffi.dylib` |
| Windows | `bclibc_ffi.dll` |

During development the path can be overridden via the `BCLIBC_FFI_PATH` environment variable.

---

## Dependencies

| Dependency | Role |
|---|---|
| [bclibc](https://github.com/ballistics-lab/bclibc) v1.1.4 | C++ ballistic solver engine (3-DOF + spin drift, RK4) — LGPL-3.0, bundled as a git submodule |
| [ffi](https://pub.dev/packages/ffi) | Dart ↔ C FFI bindings |
| [plugin_platform_interface](https://pub.dev/packages/plugin_platform_interface) | Flutter plugin platform interface |

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

[bclibc version]: https://img.shields.io/badge/bclibc-v1.1.4-grey?logo=github
[bclibc repo]: https://github.com/ballistics-lab/bclibc

[Linux]: https://img.shields.io/badge/Linux-x86__64%20%7C%20arm64-grey?logo=linux&logoColor=black&labelColor=FCC624
[Windows]: https://img.shields.io/badge/x86__64-grey?logo=windows&logoColor=black&label=Windows&labelColor=0078D4
[Android]: https://img.shields.io/badge/Android-arm64%20%7C%20armv7%20%7C%20x86__64-grey?logo=android&logoColor=white&labelColor=3DDC84
[iOS]: https://img.shields.io/badge/iOS-arm64-grey?logo=apple&logoColor=white&labelColor=000000
[macOS]: https://img.shields.io/badge/macOS-arm64%20%7C%20x86__64-grey?logo=apple&logoColor=white&labelColor=000000
