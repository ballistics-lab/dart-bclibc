// Smoke tests for AsyncCalculator.
//
// Build the native library first:
//   make native
//   dart test test/async_calculator_test.dart

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
  group('AsyncCalculator', () {
    test('barrelElevationForTarget matches sync Calculator', () async {
      final asyncCalc = AsyncCalculator();
      final syncCalc = Calculator();

      final target = Distance.meter(500);
      final asyncElev = await asyncCalc.barrelElevationForTarget(
        _makeShot(),
        target,
      );
      final syncElev = syncCalc.barrelElevationForTarget(_makeShot(), target);

      expect(
        asyncElev.in_(Unit.radian),
        closeTo(syncElev.in_(Unit.radian), 1e-9),
      );
    });

    test('setWeaponZero mutates the shot passed by the caller', () async {
      final asyncCalc = AsyncCalculator();
      final shot = _makeShot();

      expect(shot.weapon.zeroElevation.in_(Unit.radian), 0.0);
      final elev = await asyncCalc.setWeaponZero(shot, Distance.meter(300));

      expect(shot.weapon.zeroElevation.in_(Unit.radian), elev.in_(Unit.radian));
      expect(elev.in_(Unit.radian), isNot(0.0));
    });

    test('fire returns a trajectory matching sync Calculator', () async {
      final asyncCalc = AsyncCalculator();
      final syncCalc = Calculator();

      final asyncResult = await asyncCalc.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
      );
      final syncResult = syncCalc.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
      );

      expect(asyncResult.length, syncResult.length);
      expect(
        asyncResult.trajectory.last.distance.in_(Unit.meter),
        closeTo(syncResult.trajectory.last.distance.in_(Unit.meter), 1e-6),
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
