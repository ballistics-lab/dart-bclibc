# dart-bclibc

[![Made in Ukraine]][SWUBadge]

[![License]](LICENSE)
[![Dart Pub Version]][dart pub package]
[![Flutter Pub Version]][flutter pub package]
[![powered by bclibc]][bclibc repo]

[![CI](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml/badge.svg)](https://github.com/ballistics-lab/dart-bclibc/actions/workflows/ci.yml)

Dart/Flutter bindings for the [bclibc](https://github.com/ballistics-lab/bclibc)
ballistics engine — a high-performance 3-DOF + spin drift ballistic solver
with RK4/Euler integration.

This is a monorepo with two published packages:

- **[`dart/`](dart) — [`dart_bclibc`](https://pub.dev/packages/dart_bclibc)**:
  pure Dart, no Flutter dependency. FFI bindings, calculator/unit/conditions
  domain types. Works in any Dart project — CLI, server, or Flutter.
- **[`flutter/`](flutter) — [`dart_bclibc_flutter`](https://pub.dev/packages/dart_bclibc_flutter)**:
  Flutter plugin wrapper. Bundles the native library for
  Android/iOS/Linux/macOS/Windows and WebAssembly for Flutter Web, plus
  `AsyncCalculator` (needs a real web implementation, only available inside
  a Flutter app).

If you're building a plain Dart application, start with
[`dart/README.md`](dart/README.md). If you're building a Flutter app, start
with [`flutter/README.md`](flutter/README.md) — it re-exports everything
from `dart_bclibc` plus the Flutter-specific pieces.

## Building from source

```bash
git clone --recurse-submodules https://github.com/ballistics-lab/dart-bclibc.git
cd dart-bclibc
make build   # builds dart/'s native library via CMake
make test    # runs dart/'s test suite
```

The C++ engine ([bclibc](https://github.com/ballistics-lab/bclibc)) is
vendored as a git submodule, checked out separately under both `dart/bclibc`
and `flutter/bclibc` (each published package needs to be self-contained —
see `make verify-bclibc`, which checks the two copies haven't drifted apart).

## License

Copyright (C) 2026 Yaroshenko Dmytro (o-murphy)

This library is free software: you can redistribute it and/or modify it under the terms of the **GNU Lesser General Public License v3.0** as published by the Free Software Foundation.

See [LICENSE](LICENSE) for the full text.

> [!NOTE]
> `bclibc` (the ballistic solver engine) is licensed separately under the **GNU Lesser General Public License v3.0**. See [`dart/bclibc/LICENSE`](dart/bclibc/LICENSE).

> [!WARNING]
> **Risk notice.** This package performs approximate simulations of complex physical processes. Calculation results must not be considered as completely or reliably reflecting actual projectile behaviour. Results may be used for educational purposes only and must not be relied upon in any context where an incorrect calculation could cause financial harm or put a human life at risk.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<!-- REUSABLE LINKS -->

[Made in Ukraine]: https://img.shields.io/badge/made_in-Ukraine-ffd700.svg?labelColor=0057b7&style=flat-square
[SWUBadge]: https://stand-with-ukraine.pp.ua

[License]: https://img.shields.io/badge/License-LGPL%20v3-blue.svg

[Dart Pub Version]: https://img.shields.io/pub/v/dart_bclibc?logo=dart&cacheSeconds=0
[dart pub package]: https://pub.dev/packages/dart_bclibc
[Flutter Pub Version]: https://img.shields.io/pub/v/dart_bclibc_flutter?logo=flutter&cacheSeconds=0
[flutter pub package]: https://pub.dev/packages/dart_bclibc_flutter

[bclibc repo]: https://github.com/ballistics-lab/bclibc
[powered by bclibc]:
https://img.shields.io/badge/bclibc-0d1228?logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI%2FPgo8IURPQ1RZUEUgc3ZnIFBVQkxJQyAiLS8vVzNDLy9EVEQgU1ZHIDIwMDEwOTA0Ly9FTiIgImh0dHA6Ly93d3cudzMub3JnL1RSLzIwMDEvUkVDLVNWRy0yMDAxMDkwNC9EVEQvc3ZnMTAuZHRkIj4KPHN2ZyB2ZXJzaW9uPSIxLjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEwMjQuMDAwMDAwcHQiIGhlaWdodD0iMTAyNC4wMDAwMDBwdCIgdmlld0JveD0iMCAwIDEwMjQuMDAwMDAwIDEwMjQuMDAwMDAwIiBwcmVzZXJ2ZUFzcGVjdFJhdGlvPSJ4TWlkWU1pZCBtZWV0Ij4KCTxjaXJjbGUgY3g9IjUxMiIgY3k9IjUxMiIgcj0iNTEyIiBmaWxsPSIjMGQxMjI4IiAvPgoJPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTEwMCwxMTI0KSBzY2FsZSgwLjEyMDAwMCwtMC4xMjAwMDApIiBmaWxsPSIjRkZGRkZGIiBzdHJva2U9Im5vbmUiPgoJCTxwYXRoIGQ9Ik01MDU1IDgwNzEgYy0xNjcgLTMzMyAtMjczIC03NjggLTI5MiAtMTE5OCBsLTYgLTE0MyAzNDYgMCAzNDcgMCAwCjYzIGMwIDI3NSAtODAgNzMxIC0xNzUgMTAwNyAtMzkgMTEyIC0xNDUgMzQzIC0xNjMgMzU0IC03IDQgLTI5IC0yOCAtNTcgLTgzegptLTE1IC0yODkgYy00NiAtMjI1IC05MCAtNjYzIC05MCAtODk0IDAgLTEwNCAtMiAtMTA4IC02MSAtMTA4IGwtNDkgMCAwIDc4CmMxIDE1OSA0OCA0ODIgMTAxIDY5MCAzNCAxMzQgMTE5IDM5NiAxMjUgMzg5IDMgLTMgLTkgLTcyIC0yNiAtMTU1eiIgLz4KCQk8cGF0aCBkPSJNNDcxMCA2NDA2IGwwIC0yNDQgMjMgLTYgYzEyIC0zIDMyIC02IDQ1IC02IGwyMiAwIDAgMjI1IDAgMjI1IDY1IDAKNjUgMCAwIC0yMjUgMCAtMjI1IDI4MyAyIDI4MiAzIDMgMjQ4IDIgMjQ3IC0zOTUgMCAtMzk1IDAgMCAtMjQ0eiIgLz4KCQk8cGF0aCBkPSJNNDQyNCA2MTExIGMtMTggLTUgLTQ4IC0xOCAtNjggLTMwIC0xMzcgLTg1IC0xMjAgLTMwMCAyOSAtMzcwIGw0NgotMjEgLTMgLTUzMyAtMyAtNTMyIC0yMyAtNTggYy0xOCAtNDUgLTU0NSAtODUwIC04NzkgLTEzNDMgLTc2IC0xMTMgLTExMgotMjkxIC04MyAtNDE1IDQxIC0xNzcgMTY5IC0zMTIgMzQwIC0zNTkgNTkgLTE3IDI1OTMgLTE1IDI2NTUgMiAxMTQgMzAgMjMzCjEyMiAyODcgMjI0IDc2IDE0MiA3NyAzNDMgMyA0ODYgLTI4IDU0IC0xMzMgMjEzIC01NzMgODc1IC0xNzYgMjY2IC0zMzEgNTA5Ci0zNDQgNTQwIC0yMyA1OCAtMjMgNjAgLTI2IDU4OCBsLTMgNTMwIDQ1IDE4IGM1MiAyMiAxMDEgODAgMTE3IDE0MSAyNCA5MAotMjMgMTk2IC0xMDYgMjM2IC01NCAyNiAtMTk5IDM1IC0yMDEgMTMgLTEgLTcgLTIgLTE3IC0zIC0yMiAwIC01IC04OCAtNwotMjA4IC0zIC0xNTQgNCAtMjA0IDIgLTE5OSAtNiA0IC03IDE1IC0xMiAyNiAtMTIgMTAgMCA5MiAtMTMgMTgxIC0yOSA5MCAtMTYKMjA2IC0zMyAyNTggLTM3IDEwOSAtNyAxNDEgLTI3IDE0MSAtODYgLTEgLTYwIC00OCAtOTggLTEyNSAtOTggbC00NiAwIDMKLTU5MiAzIC01OTMgMjUgLTcwIGMxOCAtNTIgODAgLTE1NCAyNDEgLTM5NSA0NzYgLTcxNCA2ODkgLTEwNDMgNzEwIC0xMDk3IDE2Ci00NCAyMiAtNzkgMjIgLTE0MyAwIC0xNzQgLTgxIC0yOTMgLTIzNyAtMzQ3IC00OCAtMTcgLTEyNSAtMTggLTEzMzEgLTE4CmwtMTI4MCAwIC02NSAzMSBjLTc5IDM4IC0xMzEgODkgLTE2OCAxNjMgLTI1IDUxIC0yNyA2NiAtMjcgMTcxIDAgOTggMyAxMjIKMjIgMTYzIDEzIDI3IDExNiAxODkgMjI5IDM2MCAxMTQgMTcyIDMwOCA0NjQgNDMyIDY1MCAxMjMgMTg1IDIzNiAzNjMgMjUyCjM5NSA1NCAxMTEgNTUgMTIwIDU1IDc0MiBsMCA1NzUgLTUwIDYgYy0yNyAzIC01OCA5IC02OCAxNCAtMjcgMTEgLTQ5IDYyIC00Mgo5NCAxMCA0OCA0MyA2OSAxMTAgNzMgbDYwIDMgMCA2MCAwIDYwIC01MCAyIGMtMjcgMSAtNjQgLTIgLTgxIC02eiIgLz4KCQk8cGF0aCBkPSJNNDcwMCA1MzY5IGMwIC00MjggLTQgLTcwNyAtMTEgLTc1MiAtMjMgLTE1NyAtNTggLTIzMCAtMjYzIC01NDAKLTg0IC0xMjggLTE5NSAtMjk3IC0yNDggLTM3NyAtNTIgLTgwIC0xNjYgLTI1MyAtMjUzIC0zODUgLTg3IC0xMzIgLTE2OSAtMjYwCi0xODIgLTI4NCAtNDMgLTgyIC0yNiAtMTk3IDM5IC0yNTggNTkgLTU2IC03IC01MyAxMzI3IC01MyBsMTIyOSAwIDUyIDI4IGM5OAo1MSAxMzIgMTc2IDc3IDI4MiAtMjMgNDUgLTI2MSA0MTAgLTYzMyA5NzUgLTIzOCAzNjEgLTI1OCAzOTUgLTMwMiA1NDQgLTE0CjQ5IC0xNyAxMzkgLTIyIDcxNiBsLTUgNjYwIC0xMTUgMTcgYy02MyAxMCAtMTg1IDI5IC0yNzEgNDMgLTIxNyAzNSAtMTk5IDM5Ci0xOTkgLTQ4IDAgLTQxIC00IC0xNTQgLTEwIC0yNTMgLTUgLTk4IC0xNyAtMzEyIC0yNSAtNDc0IC05IC0xNjIgLTIwIC0zNDcKLTI1IC00MTAgLTUgLTYzIC0xMCAtMTQ1IC0xMCAtMTgyIDAgLTM4IC00IC02OCAtOCAtNjggLTggMCAtMjggNTcwIC0zOSAxMTU3CmwtNiAzMzEgLTMwIDYgYy0xNiAzIC0zOCA2IC00OCA2IC0xOCAwIC0xOSAtMjIgLTE5IC02ODF6IG0xMDMyIC0xNDI2IGM5IC0xMAo3NCAtMTA2IDE0NCAtMjE1IDcxIC0xMDggMjAzIC0zMDkgMjk0IC00NDcgMjEwIC0zMTggMjAyIC0zMDUgMjA0IC0zNTMgMSAtMzIKLTUgLTQ1IC0yNyAtNjQgbC0yOCAtMjQgLTEyMTUgMCAtMTIxNSAwIC0yNCAyNSBjLTE5IDE4IC0yNSAzNSAtMjUgNjggMCA0MQoxNyA2OSAyMDYgMzU4IDExNCAxNzMgMjU5IDM5NCAzMjMgNDkxIGwxMTYgMTc4IDYxNiAwIGM1NzQgMCA2MTcgLTEgNjMxIC0xN3oiIC8%2BCgk8L2c%2BCjwvc3ZnPgo%3D&label=powered%20by
