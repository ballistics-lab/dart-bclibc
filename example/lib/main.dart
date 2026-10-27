import 'dart:io';

import 'package:bclibc/bclibc.dart';
import 'package:flutter/widgets.dart' hide Velocity;

Shot _shot() {
  final dm = DragModel(
    bc: 0.279,
    dragTable: tableG7,
    weight: Weight.grain(300.0),
    diameter: Distance.inch(0.338),
    length: Distance.inch(1.3),
  );
  return Shot(
    weapon: Weapon(
      sightHeight: Distance.centimeter(2.1),
      twist: Distance.inch(10.0),
    ),
    ammo: Ammo(dm: dm, mv: Velocity.fps(2750.0)),
    atmo: Atmo.icao(),
  );
}

/// Solves a 500 m shot with the native engine on another isolate.
Future<double> _elevationMil() async {
  final angle = await AsyncCalculator().barrelElevationForTarget(
    _shot(),
    Distance.meter(500),
  );
  return angle.in_(Unit.mil);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Headless check used by CI (the Flatpak build runs it inside the sandbox):
  // prove the library the build hook compiled is loadable and solves a shot,
  // print a marker and exit without opening a window.
  if (Platform.environment['BCLIBC_EXAMPLE_SELFTEST'] == '1') {
    try {
      final energy = BcLibC.open().calculateEnergy(168.0, 2700.0);
      final mil = await _elevationMil();
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

  final mil = await _elevationMil();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text('bclibc: 500 m needs ${mil.toStringAsFixed(2)} MIL'),
      ),
    ),
  );
}
