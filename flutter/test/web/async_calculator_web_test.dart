// Web smoke tests for AsyncCalculator's web engine (BcLibCWeb-backed).
//
// Deliberately imports the full package barrel (package:dart_bclibc/bclibc.dart)
// rather than individual files — that's what a real consumer does, and it's
// the thing that must compile for web (bclibc.dart conditionally excludes
// the native-only Calculator/BcLibC/bclibc_bindings.g.dart pieces on web;
// see the `if (dart.library.js_interop)` branches there).
//
// Build the wasm artifact first (see bclibc_ffi_web_test.dart), then run:
//   dart test -p chrome test/web/async_calculator_web_test.dart

@TestOn('browser')
library;

import 'package:dart_bclibc_flutter/dart_bclibc_flutter.dart';
import 'package:test/test.dart';

Shot _makeShot() {
  final dm = DragModel(
    bc: 0.279,
    dragTable: tableG7,
    weight: Weight.grain(300.0),
    diameter: Distance.inch(0.338),
    length: Distance.inch(1.3),
  );
  final ammo = Ammo(dm: dm, mv: Velocity.fps(2750.0));
  final weapon = Weapon(
    sightHeight: Distance.centimeter(2.1),
    twist: Distance.inch(10.0),
  );
  return Shot(weapon: weapon, ammo: ammo, atmo: Atmo.icao());
}

void main() {
  group('AsyncCalculator (web)', () {
    test('barrelElevationForTarget returns a sane elevation', () async {
      final asyncCalc = AsyncCalculator();
      final elev = await asyncCalc.barrelElevationForTarget(
        _makeShot(),
        Distance.meter(500),
      );
      expect(elev.in_(Unit.radian), greaterThan(0.0));
    });

    test('setWeaponZero mutates the shot passed by the caller', () async {
      final asyncCalc = AsyncCalculator();
      final shot = _makeShot();

      expect(shot.weapon.zeroElevation.in_(Unit.radian), 0.0);
      final elev = await asyncCalc.setWeaponZero(shot, Distance.meter(300));

      expect(shot.weapon.zeroElevation.in_(Unit.radian), elev.in_(Unit.radian));
      expect(elev.in_(Unit.radian), isNot(0.0));
    });

    test('fire returns a non-empty trajectory', () async {
      final asyncCalc = AsyncCalculator();
      final result = await asyncCalc.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
      );
      expect(result.trajectory, isNotEmpty);
      expect(
        result.trajectory.last.distance.in_(Unit.meter),
        closeTo(1000, 1.0),
      );
    });

    test(
      'barrelElevationForTarget propagates BcException for an unreachable zero',
      () async {
        final asyncCalc = AsyncCalculator();
        await expectLater(
          asyncCalc.barrelElevationForTarget(
            _makeShot(),
            Distance.meter(1000000),
          ),
          throwsA(isA<BcException>()),
        );
      },
    );
  });
}
