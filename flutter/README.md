# bclibc_flutter (deprecated)

This package is a thin compatibility shim. Everything it used to provide now
lives in [`bclibc`](https://pub.dev/packages/bclibc), a single package for Dart,
Flutter and the web: the native library is built from bundled sources by a build
hook, and the wasm module for web is embedded.

Replace

```yaml
dependencies:
  bclibc_flutter: ^1.0.0
```

with

```yaml
dependencies:
  bclibc: ^2.0.0
```

and `package:bclibc_flutter/...` imports with `package:bclibc/...`. This shim only
re-exports `package:bclibc/bclibc.dart` and `package:bclibc/unit.dart`.
