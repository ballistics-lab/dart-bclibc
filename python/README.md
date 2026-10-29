# dart_bclibc: py-ballisticcalc engines backed by dart-bclibc

Runs [py-ballisticcalc](https://github.com/o-murphy/py-ballisticcalc)'s own test suite against this Dart package,
so there is no Dart-side copy of it to maintain. The engines hand each `Shot` to `tool/py_bridge/bridge.dart`
(one long-lived `dart run` process, one JSON line per request), which rebuilds it as dart-bclibc's `Shot` and runs it
through `toBcShot` -> `BcLibC` (FFI) -> `toTrajectoryData`.

One engine per `BcIntegrationMethod`: `dart_bclibc+rk4`, `+euler`, `+verlet`, `+rkck`, `+dopri`, `+tsitouras`.

```bash
git submodule update --init            # bclibc and py-ballisticcalc (the tests/ come from there)
pip install -e py-ballisticcalc -e python pytest      # Python >= 3.11, Dart SDK on PATH
pytest py-ballisticcalc/tests --engine=dart_bclibc+tsitouras
make py-test                           # all six methods
```

`DART_BCLIBC_BRIDGE` replaces the bridge command, `DART_BCLIBC_ROOT` the checkout it runs from.
Tests that are specific to other engines (Cash-Karp, DOPRI, Tsitouras classes of the Cython package) skip
themselves, and `dense_output` is not supported: the package returns filtered rows only.
