// Dense output at the Calculator / AsyncCalculator level: fire(denseOutput: true), getAt, getAtDistance.
//
//   dart test test/dense_calculator_test.dart

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
    zeroElevation: Angular.mil(1.0),
  );
  return Shot(weapon: weapon, ammo: ammo, atmo: Atmo.icao());
}

double _m(Distance d) => d.in_(Unit.meter);

void main() {
  group('Calculator dense output', () {
    final calc = Calculator();

    HitResult fire({bool dense = false, Distance? step}) => calc.fire(
      shot: _makeShot(),
      trajectoryRange: Distance.meter(1000),
      trajectoryStep: step ?? Distance.meter(100),
      denseOutput: dense,
    );

    test('denseOutput adds the integrator steps and keeps the rows', () {
      final plain = fire();
      final dense = fire(dense: true);
      expect(plain.denseSteps, isNull);
      expect(dense.denseSteps, isNotNull);
      expect(dense.denseSteps!.length, greaterThan(dense.length));
      expect(dense.length, plain.length);
      expect(
        _m(dense.records.last.distance),
        closeTo(_m(plain.records.last.distance), 1e-9),
      );
    });

    test('getAt: a time, a position', () {
      final hit = fire(dense: true);
      final steps = hit.denseSteps!;
      final t = 0.5 * (steps[3].time + steps[4].time);
      final byTime = calc.getAt(hit, BcBaseTrajInterpKey.time, t);
      expect(byTime.time, closeTo(t, 1e-12));
      final x = Distance.meter(250).in_(Unit.foot);
      final byX = calc.getAt(hit, BcBaseTrajInterpKey.posX, x);
      expect(_m(byX.distance), closeTo(250, 1e-6));
      expect(byX.velocity.in_(Unit.fps), lessThan(2750.0));
    });

    test('getAtDistance interpolates in the dense output', () {
      final hit = fire(dense: true);
      final at = calc.getAtDistance(hit, Distance.meter(150));
      expect(_m(at.distance), closeTo(150, 1e-6));
      // between the rows at 100 and 200 m (the bullet is falling)
      final h100 = hit.records.firstWhere((r) => _m(r.distance) > 99).height;
      final h200 = hit.records.firstWhere((r) => _m(r.distance) > 199).height;
      expect(at.height.in_(Unit.meter), lessThan(h100.in_(Unit.meter)));
      expect(at.height.in_(Unit.meter), greaterThan(h200.in_(Unit.meter)));
    });

    test('without dense output it interpolates between the rows', () {
      final dense = calc.getAtDistance(fire(dense: true), Distance.meter(150));
      final rows = calc.getAtDistance(
        fire(step: Distance.meter(50)),
        Distance.meter(150),
      );
      final coarse = calc.getAtDistance(fire(), Distance.meter(150));
      expect(_m(coarse.distance), closeTo(150, 1e-6));
      // the rows are samples of the same trajectory: a few centimetres at most
      expect(
        coarse.height.in_(Unit.meter),
        closeTo(dense.height.in_(Unit.meter), 0.02),
      );
      expect(
        coarse.velocity.in_(Unit.fps),
        closeTo(dense.velocity.in_(Unit.fps), 1.0),
      );
      // a finer row step is closer
      expect(
        (rows.height.in_(Unit.meter) - dense.height.in_(Unit.meter)).abs(),
        lessThanOrEqualTo(
          (coarse.height.in_(Unit.meter) - dense.height.in_(Unit.meter)).abs(),
        ),
      );
    });

    test('a distance between the last two rows uses the last three rows', () {
      final at = calc.getAtDistance(fire(), Distance.meter(950));
      expect(_m(at.distance), closeTo(950, 1e-6));
    });

    test('a row at the distance is returned as it is', () {
      final hit = fire();
      final at = calc.getAtDistance(hit, Distance.meter(300));
      final row = hit.records.firstWhere(
        (r) => (_m(r.distance) - 300).abs() < 1e-6,
      );
      expect(at.time, row.time);
    });

    test('HitResult.getAtDistance stays the nearest row', () {
      final near = fire().getAtDistance(Distance.meter(150));
      expect(
        _m(near.distance),
        closeTo(200, 1e-6),
      ); // the first row at or beyond it, not an interpolation
    });

    test('errors', () {
      final plain = fire();
      expect(
        () => calc.getAt(plain, BcBaseTrajInterpKey.time, 0.5),
        throwsStateError,
      );
      expect(
        () => calc.getAtDistance(plain, Distance.meter(5000)),
        throwsRangeError,
      );
      expect(
        () => calc.getAtDistance(
          calc.fire(
            shot: _makeShot(),
            trajectoryRange: Distance.meter(100),
            trajectoryStep: Distance.meter(100),
          ),
          Distance.meter(50),
        ),
        throwsStateError,
      ); // two rows only
      expect(
        () => calc.getAt(fire(dense: true), BcBaseTrajInterpKey.time, 1e6),
        throwsA(
          isA<BcException>().having(
            (e) => e.kind,
            'kind',
            BcErrorKind.outOfBounds,
          ),
        ),
      );
    });

    test('the adaptive methods fire with dense output and tolerances', () {
      final c = Calculator(method: BcIntegrationMethod.dopri);
      final hit = c.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
        denseOutput: true,
        relativeTolerance: 1e-9,
        absoluteTolerance: 1e-9,
      );
      expect(hit.denseSteps, isNotEmpty);
      expect(
        _m(c.getAtDistance(hit, Distance.meter(555)).distance),
        closeTo(555, 1e-6),
      );
      expect(
        () => c.fire(
          shot: _makeShot(),
          trajectoryRange: Distance.meter(1000),
          denseOutput: true,
          relativeTolerance: -1.0,
        ),
        throwsA(
          isA<BcException>().having(
            (e) => e.kind,
            'kind',
            BcErrorKind.invalidArgument,
          ),
        ),
      );
    });
  });

  group('AsyncCalculator dense output', () {
    test('fire, getAt and getAtDistance match the sync Calculator', () async {
      final sync = Calculator();
      final asy = AsyncCalculator();
      final shot = _makeShot();
      final hit = await asy.fire(
        shot: shot,
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
        denseOutput: true,
      );
      final syncHit = sync.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(1000),
        trajectoryStep: Distance.meter(100),
        denseOutput: true,
      );
      expect(hit.denseSteps!.length, syncHit.denseSteps!.length);

      final a = await asy.getAtDistance(hit, Distance.meter(150));
      final s = sync.getAtDistance(syncHit, Distance.meter(150));
      expect(a.height.in_(Unit.meter), closeTo(s.height.in_(Unit.meter), 1e-9));
      expect(a.time, closeTo(s.time, 1e-12));

      final t = hit.denseSteps![2].time;
      final byTime = await asy.getAt(hit, BcBaseTrajInterpKey.time, t);
      expect(byTime.time, closeTo(t, 1e-12));
    });

    test('getAt without dense output is a StateError', () async {
      final asy = AsyncCalculator();
      final hit = await asy.fire(
        shot: _makeShot(),
        trajectoryRange: Distance.meter(500),
        trajectoryStep: Distance.meter(100),
      );
      await expectLater(
        asy.getAt(hit, BcBaseTrajInterpKey.time, 0.1),
        throwsStateError,
      );
    });
  });
}
