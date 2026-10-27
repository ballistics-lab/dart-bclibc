// The build hook, run the way the SDK runs it (hooks' own test harness), on the
// host target: it has to produce exactly the code asset the `@Native` bindings
// are declared against, and the file has to exist. Cheap first line of defence;
// whether the library lands in an app bundle and loads on the target is checked
// by scripts/ci/flutter-smoke.sh.
@TestOn('vm')
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as hook;

void main() {
  test(
    'build hook emits one bundled code asset for the bindings',
    () async {
      await testCodeBuildHook(
        mainMethod: hook.main,
        check: (input, output) {
          final assets = output.assets.code;
          expect(assets, hasLength(1));
          final asset = assets.single;
          expect(asset.id, 'package:bclibc/ffi/bclibc_bindings.g.dart');
          expect(asset.linkMode, isA<DynamicLoadingBundled>());
          expect(asset.file, isNotNull);
          expect(File.fromUri(asset.file!).existsSync(), isTrue);
          // The file name differs per target (libbclibc_ffi.so / .dylib,
          // bclibc_ffi.dll); the hook's own checks and the CI scripts rely on it.
          expect(
            asset.file!.pathSegments.last,
            input.config.code.targetOS.libraryFileName(
              'bclibc_ffi',
              DynamicLoadingBundled(),
            ),
          );
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
