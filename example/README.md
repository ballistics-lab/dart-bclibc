# bclibc example

A small Flutter app that solves a shot with `bclibc` (native engine on another
isolate). It is also what CI builds as an **offline Flatpak** with
[flutpak](https://github.com/o-murphy/flutpak), the same way `ebalistyka` is
built, to prove the package's build hook works inside the Flatpak sandbox.

```bash
cd example
flutter run -d linux
BCLIBC_EXAMPLE_SELFTEST=1 flutter run -d linux   # headless check, exits 0/1
```
