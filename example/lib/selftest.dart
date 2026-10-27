// Headless self-test used by CI: `BCLIBC_EXAMPLE_SELFTEST=1 bclibc_example`
// loads the native engine, solves a shot, prints a marker and exits (the
// Flatpak build runs it inside the sandbox). Native only: the web build has no
// `dart:io` and uses the wasm backend instead.
export 'selftest_io.dart' if (dart.library.js_interop) 'selftest_web.dart';
