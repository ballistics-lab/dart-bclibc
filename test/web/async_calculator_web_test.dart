// Web smoke tests for AsyncCalculator's web engine (BcLibCWeb-backed).
//
// Deliberately imports the full package barrel (package:bclibc/bclibc.dart)
// rather than individual files — that's what a real consumer does, and it's
// the thing that must compile for web (bclibc.dart conditionally excludes
// the native-only Calculator/BcLibC/bclibc_bindings.g.dart pieces on web;
// see the `if (dart.library.js_interop)` branches there).
//
// Run with:
//   dart test -p chrome test/web/async_calculator_web_test.dart

@TestOn('browser')
library;

import 'package:bclibc/bclibc.dart';
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
      expect(result.records, isNotEmpty);
      expect(result.records.last.distance.in_(Unit.meter), closeTo(1000, 1.0));
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

  group('AsyncCalculator dense output (web)', () {
    test('fire with dense output, getAt and getAtDistance', () async {
      final asyncCalc = AsyncCalculator();
      final hit = await asyncCalc.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
        denseOutput: true,
      );
      expect(hit.denseSteps, isNotEmpty);
      expect(hit.denseSteps!.length, greaterThan(hit.length));

      final at = await asyncCalc.getAtDistance(hit, Distance.meter(150));
      expect(at.distance.in_(Unit.meter), closeTo(150, 1e-6));
      final t = hit.denseSteps![2].time;
      final byTime = await asyncCalc.getAt(hit, BcBaseTrajInterpKey.time, t);
      expect(byTime.time, closeTo(t, 1e-12));
    });

    test('without dense output getAtDistance interpolates the rows', () async {
      final asyncCalc = AsyncCalculator();
      final hit = await asyncCalc.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
      );
      final at = await asyncCalc.getAtDistance(hit, Distance.meter(150));
      expect(at.distance.in_(Unit.meter), closeTo(150, 1e-6));
      await expectLater(
        asyncCalc.getAt(hit, BcBaseTrajInterpKey.time, 0.1),
        throwsStateError,
      );
    });

    test(
      'a value beyond the dense output is a typed outOfBounds error',
      () async {
        final asyncCalc = AsyncCalculator();
        final hit = await asyncCalc.fire(
          shot: _makeShot(),
          trajectoryRange: Distance.meter(500),
          trajectoryStep: Distance.meter(100),
          denseOutput: true,
        );
        await expectLater(
          asyncCalc.getAt(hit, BcBaseTrajInterpKey.time, 1e6),
          throwsA(
            isA<BcException>().having(
              (e) => e.kind,
              'kind',
              BcErrorKind.outOfBounds,
            ),
          ),
        );
      },
    );
  });
}
