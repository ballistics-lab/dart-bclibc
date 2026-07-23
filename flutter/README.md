# dart_bclibc_flutter

Flutter plugin wrapper for [`dart_bclibc`](../dart) — bundles the native
`bclibc` ballistics engine for Android/iOS/Linux/macOS/Windows and the
wasm build for Flutter Web.

For a pure Dart project (no Flutter), depend on
[`dart_bclibc`](../dart) directly instead — see its README for the
`dart run dart_bclibc:build_native` native-build step.

## Usage

```yaml
dependencies:
  dart_bclibc_flutter: ^0.1.0-beta.1
```

```dart
import 'package:dart_bclibc_flutter/bclibc.dart';

final calc = Calculator();       // synchronous, native FFI
final asyncCalc = AsyncCalculator(); // off-isolate on native, wasm on web
```

Everything exported by `package:dart_bclibc/bclibc.dart` (calculator/unit/
conditions/shot/trajectory types, the synchronous `Calculator`) is
re-exported here, plus `AsyncCalculator`, which lives in this package
because it needs a real web (wasm) implementation on Flutter Web.

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
package via `flutter.assets` in `pubspec.yaml` — `flutter build web` picks it
up automatically, no extra setup needed in the consuming app.

```dart
import 'package:dart_bclibc_flutter/bclibc.dart';

// Works unmodified on web — AsyncCalculator picks the wasm engine
// automatically when compiled for web.
final calc = AsyncCalculator();
final elev = await calc.barrelElevationForTarget(shot, Distance.meter(500));
```

To rebuild the wasm artifact from source (only needed if you're modifying
`bclibc` itself):

```bash
bclibc/build_wasm.sh   # self-installs a pinned Emscripten SDK on first run
cp bclibc/build/web/bclibc_ffi.{js,wasm} assets/wasm/
```

## Native platform builds

Android/iOS/Linux/macOS/Windows all build `bclibc_ffi` from the vendored
`bclibc/` git submodule (this package carries its own copy — see the repo
root's `Makefile`'s `verify-bclibc` target, which checks it stays in sync
with `dart/bclibc`'s copy) via each platform's native build system
(CMake/Gradle/CocoaPods) — no prebuilt binaries, no network access needed at
build time. `flutter build`/`flutter run` bundle the result automatically.

See the [repo root README](../README.md) and [`dart_bclibc`'s
README](../dart/README.md) for the full API reference.
