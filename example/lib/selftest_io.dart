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
    stdout.writeln('bclibc self-test ok: E=$energy elevation=$mil MIL');
    exit(0);
  } catch (e, st) {
    stderr.writeln('bclibc self-test FAILED: $e\n$st');
    exit(1);
  }
}
