// Web placeholder for calculator.dart's conditional export in bclibc.dart.
//
// Calculator (the synchronous, native-only wrapper around BcLibC) has no web
// equivalent by design — dart:ffi doesn't exist on web, and calculator.dart
// imports it unconditionally, so it can't be compiled for web at all. Web
// consumers use AsyncCalculator instead, which is exported unconditionally
// (it's platform-agnostic; see calculator_core.dart / async_engine_web.dart).
