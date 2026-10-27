import 'package:bclibc/bclibc.dart';
import 'package:flutter/widgets.dart' hide Velocity;

import 'selftest.dart';

Shot shot() {
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

/// Solves a 500 m shot: the native engine on another isolate, or the embedded
/// wasm module on the web.
Future<double> elevationMil() async {
  final angle = await AsyncCalculator().barrelElevationForTarget(
    shot(),
    Distance.meter(500),
  );
  return angle.in_(Unit.mil);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runSelfTestIfRequested(elevationMil);

  final mil = await elevationMil();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text('bclibc: 500 m needs ${mil.toStringAsFixed(2)} MIL'),
      ),
    ),
  );
}
