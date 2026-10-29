// Regenerates lib/ffi/bclibc_bindings.g.dart from the bclibc C API header.
// Run with `dart run tool/ffigen.dart` (or `make ffigen`).
import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  final functions = RegExp(r'^BCLIBCFFI_.*');
  final types = RegExp(r'^BC.*');

  final generator = FfiGenerator(
    input: Input(
      entryPoints: [
        packageRoot.resolve('bclibc/include/bclibc/ffi/bclibc_ffi.h'),
      ],
      include: (header) => header.path.endsWith('bclibc_ffi.h'),
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/ffi/bclibc_bindings.g.dart'),
      ),
      style: const NativeExternalBindings(
        assetId: 'package:bclibc/ffi/bclibc_bindings.g.dart',
      ),
      preamble: '''
// AUTO-GENERATED – do not edit.
// Run: dart run tool/ffigen.dart
//
// ignore_for_file: type=lint
// ignore_for_file: return_of_invalid_type
// ignore_for_file: unnecessary_non_null_assertion
// ignore_for_file: unused_element
''',
    ),
    visitors: [
      Visitor(
        func: (node) {
          if (functions.hasMatch(node.originalName)) node.isIncluded = true;
        },
        struct: (node) {
          if (types.hasMatch(node.originalName)) node.isIncluded = true;
        },
        enumClass: (node) {
          if (types.hasMatch(node.originalName)) {
            node.isIncluded = true;
            node.silenceWarning = true;
          }
        },
      ),
    ],
  );
  await generator.generate();
}
