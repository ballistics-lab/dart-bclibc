// Builds the standalone libbclibc_ffi shared library and copies it into
// this package's own `lib/native/<platform>/` directory, where
// `_openLibrary()` (lib/ffi/bclibc_ffi.dart) resolves it via a `package:`
// URI — independent of the caller's cwd. Mirrors the pattern used by the
// sibling `ob-dump` project's `dart run ob_dump_reader:build`
// (dart/lib/src/build_util.dart).
//
// `flutter build`/`flutter run` (via dart_bclibc_flutter) bundle the library
// automatically via the platform CMake integration — this script only covers
// plain Dart projects (`dart test`, `dart run`), which never run a platform
// build, so consumers should call it once before either:
//
//   dart run dart_bclibc:build_native
//
// Usage: dart run dart_bclibc:build_native [BUILD_TYPE]
// BUILD_TYPE defaults to the BCLIBC_BUILD_TYPE env var, or "Release".
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final buildType = args.isNotEmpty
      ? args[0]
      : Platform.environment['BCLIBC_BUILD_TYPE'] ?? 'Release';

  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    stderr.writeln(
      'error: dart_bclibc:build_native only supports Linux/macOS/Windows '
      'desktop targets. Android/iOS get the native library bundled by '
      'dart_bclibc_flutter\'s platform build instead.',
    );
    exit(1);
  }

  // `dart run dart_bclibc:build_native` compiles this script to a kernel
  // snapshot cached under the *caller's* .dart_tool/pub/bin/ — Platform.script
  // then points at that snapshot, not at this file's real location in
  // pub-cache. Isolate.resolvePackageUri goes through the actual
  // package_config.json resolution instead, so it's correct regardless of
  // pub-cache vs. path dependency vs. snapshot caching.
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dart_bclibc/bclibc.dart'),
  );
  if (libUri == null) {
    stderr.writeln('error: could not resolve package:dart_bclibc');
    exit(1);
  }
  final packageRoot = Directory.fromUri(libUri.resolve('..'));

  final bclibcSrc = Directory(p.join(packageRoot.path, 'bclibc'));
  final bclibcCMakeLists = File(p.join(bclibcSrc.path, 'CMakeLists.txt'));
  if (!bclibcCMakeLists.existsSync()) {
    stderr.writeln(
      'error: ${bclibcCMakeLists.path} not found.\n'
      'If dart_bclibc is a path dependency, run `git submodule update --init` in it first.',
    );
    exit(1);
  }

  final buildDir = Directory(p.join(packageRoot.path, 'build'));
  if (!buildDir.existsSync()) buildDir.createSync();

  final cmakeCache = File(p.join(buildDir.path, 'CMakeCache.txt'));
  if (!cmakeCache.existsSync()) {
    _run('cmake', [
      '-S',
      bclibcSrc.path,
      '-B',
      buildDir.path,
      '-DCMAKE_BUILD_TYPE=$buildType',
    ]);
  }
  _run('cmake', [
    '--build',
    buildDir.path,
    '--config',
    buildType,
    '--parallel',
    '${_nproc()}',
  ]);

  final platform = Platform.operatingSystem; // 'linux', 'macos', 'windows'
  final libName = Platform.isWindows
      ? 'bclibc_ffi.dll'
      : Platform.isMacOS
      ? 'libbclibc_ffi.dylib'
      : 'libbclibc_ffi.so';

  final candidates = [
    p.join(buildDir.path, libName),
    p.join(buildDir.path, buildType, libName),
  ];
  final builtLib = candidates
      .map((c) => File(c))
      .firstWhere(
        (f) => f.existsSync(),
        orElse: () => throw FileSystemException(
          'Could not find built library (tried ${candidates.join(", ")})',
        ),
      );

  final targetDir = Directory(p.join(packageRoot.path, 'lib', 'native', platform));
  if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
  final targetLib = File(p.join(targetDir.path, libName));
  builtLib.copySync(targetLib.path);

  stdout.writeln('bclibc_ffi built and copied to: ${targetLib.path}');
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
