import 'dart:io';

import 'package:bclibc/bclibc.dart';

/// Runs the self-test and exits the process when `BCLIBC_EXAMPLE_SELFTEST=1`.
Future<void> runSelfTestIfRequested(
  Future<double> Function() elevationMil,
) async {
  if (Platform.environment['BCLIBC_EXAMPLE_SELFTEST'] != '1') return;
  try {
    final energy = BcLibC.open().calculateEnergy(168.0, 2700.0);
    final mil = await elevationMil();
    if (energy <= 0 || !mil.isFinite) {
      throw StateError('implausible result: energy=$energy, elevation=$mil');
    }
    _report('bclibc self-test ok: E=$energy elevation=$mil MIL');
    exit(0);
  } catch (e, st) {
    _report('bclibc self-test FAILED: $e\n$st', error: true);
    exit(1);
  }
}

/// Prints the result, and also writes it to `BCLIBC_EXAMPLE_SELFTEST_OUT` when
/// set: a GUI executable (the Windows runner) has no reliable stdout.
void _report(String message, {bool error = false}) {
  (error ? stderr : stdout).writeln(message);
  final out = Platform.environment['BCLIBC_EXAMPLE_SELFTEST_OUT'];
  if (out == null || out.isEmpty) return;
  // A failed write (e.g. the macOS App Sandbox forbids the path) must not keep
  // the process from reaching exit(): the result is on stdout/stderr anyway.
  try {
    File(out).writeAsStringSync('$message\n');
  } on Object catch (e) {
    stderr.writeln('could not write self-test result to $out: $e');
  }
}
