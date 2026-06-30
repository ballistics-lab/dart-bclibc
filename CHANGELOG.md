# Changelog

## 0.1.0-beta.1

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

### Notes
- Requires `bclibc` submodule to be initialised before building:
  `git submodule update --init`
- Platforms: Linux, Windows, Android (arm64-v8a, x86_64), iOS, macOS
- Native library: `libbclibc_ffi.so` / `bclibc_ffi.dll` /
  `libbclibc_ffi.dylib` — compiled from the bundled `bclibc/` submodule
  (v1.1.4, LGPL-3.0) by each platform's own build system
