// Builds the standalone libbclibc_ffi shared library into `build/bclibc/`
// (relative to the caller's cwd), which is one of the paths `BcLibC.open()`
// (lib/ffi/bclibc_ffi.dart) tries when dlopen-ing the native library.
//
// `flutter build`/`flutter run` bundle the library automatically via the
// platform CMake integration (linux/, macos/, ... CMakeLists.txt) — this
// script only covers `flutter test`/`dart test`, which never run a platform
// build, so consumers should call it before testing:
//
//   dart run dart_bclibc:build_native
//
// Usage: dart run dart_bclibc:build_native [BUILD_TYPE]
// BUILD_TYPE defaults to the BCLIBC_BUILD_TYPE env var, or "Debug".
import 'dart:io';

void main(List<String> args) {
  final buildType = args.isNotEmpty
      ? args[0]
      : Platform.environment['BCLIBC_BUILD_TYPE'] ?? 'Debug';

  // Platform.script resolves to this file's own location, whether dart_bclibc
  // was resolved from pub-cache or a local path dependency — unlike parsing
  // .dart_tool/package_config.json from the caller's side, this works
  // regardless of which package invokes `dart run dart_bclibc:build_native`.
  final packageRoot = Platform.script.resolve('..');
  // Trailing slash matters: without it, Uri.resolve treats "bclibc" as a
  // file segment and the next .resolve() call drops it instead of
  // appending to it.
  final bclibcSrc = packageRoot.resolve('bclibc/');
  final bclibcCMakeListsUri = bclibcSrc.resolve('CMakeLists.txt');
  final bclibcCMakeLists = File.fromUri(bclibcCMakeListsUri);

  if (!bclibcCMakeLists.existsSync()) {
    stderr.writeln(
      'error: ${bclibcCMakeListsUri.toFilePath()} not found.\n'
      'If dart_bclibc is a path dependency, run `git submodule update --init` in it first.',
    );
    exit(1);
  }

  const buildDir = 'build/bclibc';
  final cmakeCache = File('$buildDir/CMakeCache.txt');
  if (!cmakeCache.existsSync()) {
    _run('cmake', [
      '-S',
      bclibcSrc.toFilePath(),
      '-B',
      buildDir,
      '-DCMAKE_BUILD_TYPE=$buildType',
    ]);
  }
  _run('cmake', ['--build', buildDir, '--parallel', '${_nproc()}']);
}

int _nproc() {
  try {
    final result = Process.runSync('nproc', const []);
    if (result.exitCode == 0) {
      return int.parse((result.stdout as String).trim());
    }
  } catch (_) {
    // fall through to default
  }
  return 4;
}

void _run(String executable, List<String> arguments) {
  stdout.writeln('\$ $executable ${arguments.join(' ')}');
  final result = Process.runSync(
    executable,
    arguments,
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
}
