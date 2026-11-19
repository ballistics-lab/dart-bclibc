// WASM/web smoke tests for BcLibCWeb.
//
// Runs against the wasm module embedded in the package
// (lib/ffi/bclibc_wasm.g.dart) -- nothing to build or stage first. To rebuild
// that module from source (one bare module, zig, no Emscripten):
//   uv run --with ziglang make build-wasm
//
// Run with (any browser with WebAssembly):
//   dart test -p chrome test/web/bclibc_ffi_web_test.dart

@TestOn('browser')
library;

import 'package:bclibc/ffi/bclibc_ffi_web.dart';
import 'package:test/test.dart';

final _g7Table = [
  BcDragPoint(0.00, 0.1198),
  BcDragPoint(0.05, 0.1197),
  BcDragPoint(0.10, 0.1196),
  BcDragPoint(0.15, 0.1194),
  BcDragPoint(0.20, 0.1193),
  BcDragPoint(0.25, 0.1194),
  BcDragPoint(0.30, 0.1194),
  BcDragPoint(0.35, 0.1194),
  BcDragPoint(0.40, 0.1193),
  BcDragPoint(0.45, 0.1193),
  BcDragPoint(0.50, 0.1194),
  BcDragPoint(0.55, 0.1193),
  BcDragPoint(0.60, 0.1194),
  BcDragPoint(0.65, 0.1197),
  BcDragPoint(0.70, 0.1202),
  BcDragPoint(0.725, 0.1207),
  BcDragPoint(0.75, 0.1215),
  BcDragPoint(0.775, 0.1226),
  BcDragPoint(0.80, 0.1242),
  BcDragPoint(0.825, 0.1266),
  BcDragPoint(0.85, 0.1306),
  BcDragPoint(0.875, 0.1368),
  BcDragPoint(0.90, 0.1464),
  BcDragPoint(0.925, 0.1660),
  BcDragPoint(0.95, 0.2054),
  BcDragPoint(0.975, 0.2993),
  BcDragPoint(1.0, 0.3803),
  BcDragPoint(1.025, 0.4015),
  BcDragPoint(1.05, 0.4043),
  BcDragPoint(1.075, 0.4034),
  BcDragPoint(1.10, 0.4014),
  BcDragPoint(1.15, 0.3955),
  BcDragPoint(1.20, 0.3884),
  BcDragPoint(1.30, 0.3732),
  BcDragPoint(1.40, 0.3579),
  BcDragPoint(1.50, 0.3440),
  BcDragPoint(1.60, 0.3315),
  BcDragPoint(1.80, 0.3106),
  BcDragPoint(2.00, 0.2950),
  BcDragPoint(2.20, 0.2838),
  BcDragPoint(2.40, 0.2772),
  BcDragPoint(2.60, 0.2745),
  BcDragPoint(2.80, 0.2745),
  BcDragPoint(3.00, 0.2763),
];

BcShot _makeShot({
  double barrelElevationRad = 0.0,
  BcIntegrationMethod method = BcIntegrationMethod.rk4,
}) => BcShot(
  bc: 0.279,
  weightGrain: 300.0,
  diameterInch: 0.338,
  lengthInch: 1.3,
  muzzleVelocityFps: 2750.0,
  sightHeightFt: 0.21 / 3.28084,
  twistInch: 10.0,
  tempC: 15.0,
  pressureHpa: 1013.25,
  altitudeFt: 0.0,
  humidity: 0.0,
  dragTable: _g7Table,
  lookAngleRad: 0.0,
  barrelElevationRad: barrelElevationRad,
  method: method,
);

void main() {
  late BcLibCWeb bc;

  setUpAll(() async {
    bc = await BcLibCWeb.open();
  });

  test('calculateEnergy matches expected value', () {
    final e = bc.calculateEnergy(300.0, 2750.0);
    expect(e, closeTo(5036, 50));
  });

  test('calculateOgw is positive', () {
    final ogw = bc.calculateOgw(300.0, 2750.0);
    expect(ogw, greaterThan(0.0));
  });

  test('getCorrection at zero offset is zero', () {
    expect(bc.getCorrection(1000.0, 0.0), closeTo(0.0, 1e-9));
  });

  test('findZeroAngleShot returns non-zero elevation for 1000 ft zero', () {
    final shot = _makeShot();
    final angle = bc.findZeroAngleShot(shot, 1000.0);
    expect(angle, greaterThan(0.0));
    expect(angle, lessThan(0.1));
  });

  test('a solve that fails is a BcException, and the module keeps working', () {
    // Out of range: the module throws a C++ exception inside wasm, the flat C ABI catches it and returns an error
    // code, as the native library does (no trap, no exception across the WebAssembly boundary).
    expect(
      () => bc.findZeroAngleShot(_makeShot(), 60000.0),
      throwsA(isA<BcException>()),
    );
    // the instance is still good
    expect(bc.findZeroAngleShot(_makeShot(), 1000.0), greaterThan(0.0));
  });

  test('findApexShot returns apex above muzzle height', () {
    final shot = _makeShot(barrelElevationRad: 0.01);
    final apex = bc.findApexShot(shot);
    expect(apex.heightFt, greaterThan(0.0));
    expect(apex.distanceFt, greaterThan(0.0));
  });

  test('integrateShot velocity decreases monotonically', () {
    final shot = _makeShot();
    final request = BcTrajectoryRequest(
      rangeLimitFt: 1000.0 * 3.28084,
      rangeStepFt: 100.0 * 3.28084,
    );
    final result = bc.integrateShot(shot, request);
    expect(result.trajectory, isNotEmpty);
    for (var i = 1; i < result.trajectory.length; i++) {
      expect(
        result.trajectory[i].velocityFps,
        lessThan(result.trajectory[i - 1].velocityFps),
      );
    }
  });

  test('integrateShot distance increases monotonically', () {
    final shot = _makeShot();
    final request = BcTrajectoryRequest(
      rangeLimitFt: 1000.0 * 3.28084,
      rangeStepFt: 100.0 * 3.28084,
    );
    final result = bc.integrateShot(shot, request);
    for (var i = 1; i < result.trajectory.length; i++) {
      expect(
        result.trajectory[i].distanceFt,
        greaterThan(result.trajectory[i - 1].distanceFt),
      );
    }
  });

  for (final method in [
    BcIntegrationMethod.euler,
    BcIntegrationMethod.velocityVerlet,
    BcIntegrationMethod.rkck,
    BcIntegrationMethod.dopri,
    BcIntegrationMethod.tsitouras,
  ]) {
    test('integrateShot ${method.name} method also produces a trajectory', () {
      final shot = _makeShot(method: method);
      final request = BcTrajectoryRequest(
        rangeLimitFt: 500.0 * 3.28084,
        rangeStepFt: 100.0 * 3.28084,
      );
      final result = bc.integrateShot(shot, request);
      expect(result.trajectory, isNotEmpty);
    });
  }

  test('integrateAtShot returns interception at a specific distance', () {
    final shot = _makeShot();
    final targetFt = 500.0 * 3.28084;
    final intercept = bc.integrateAtShot(
      shot,
      BcBaseTrajInterpKey.posX,
      targetFt,
    );
    expect(intercept.fullData.distanceFt, closeTo(targetFt, targetFt * 0.01));
  });

  // ── Typed errors and dense output ─────────────────────────────────────────

  group('typed errors', () {
    BcDenseResult dense([BcIntegrationMethod m = BcIntegrationMethod.rk4]) =>
        bc.integrateDenseShot(
          _makeShot(barrelElevationRad: 0.005, method: m),
          BcTrajectoryRequest(
            rangeLimitFt: 1000.0 * 3.28084,
            rangeStepFt: 100.0 * 3.28084,
          ),
        );

    test('a value beyond the dense output is outOfBounds, with its range', () {
      final steps = dense().steps;
      expect(
        () => bc.denseGetAt(steps, BcBaseTrajInterpKey.time, 1e6),
        throwsA(
          isA<BcException>()
              .having((e) => e.kind, 'kind', BcErrorKind.outOfBounds)
              .having((e) => e.requestedValue, 'requested', 1e6)
              .having((e) => e.minimumValue, 'minimum', steps.first.time)
              .having((e) => e.maximumValue, 'maximum', steps.last.time),
        ),
      );
    });

    test('fewer than 3 steps is a domain error', () {
      final steps = dense().steps.take(2).toList();
      expect(
        () => bc.denseGetAt(steps, BcBaseTrajInterpKey.time, 0.0),
        throwsA(
          isA<BcException>().having((e) => e.kind, 'kind', BcErrorKind.domain),
        ),
      );
      expect(
        () => bc.denseGetAt(const [], BcBaseTrajInterpKey.time, 0.0),
        throwsA(
          isA<BcException>().having((e) => e.kind, 'kind', BcErrorKind.domain),
        ),
      );
    });

    test('a tolerance out of range is invalidArgument', () {
      expect(
        () => bc.integrateDenseShot(
          _makeShot(method: BcIntegrationMethod.dopri),
          BcTrajectoryRequest(rangeLimitFt: 1000.0, rangeStepFt: 100.0),
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

    test('a drag table of one point is invalidArgument', () {
      final one = BcShot(
        bc: 0.279,
        weightGrain: 300.0,
        diameterInch: 0.338,
        lengthInch: 1.3,
        muzzleVelocityFps: 2750.0,
        sightHeightFt: 0.07,
        twistInch: 10.0,
        tempC: 15.0,
        pressureHpa: 1013.25,
        altitudeFt: 0.0,
        dragTable: [BcDragPoint(1.0, 0.3)],
        lookAngleRad: 0.0,
        barrelElevationRad: 0.0,
      );
      expect(
        () => bc.findZeroAngleShot(one, 300.0),
        throwsA(
          isA<BcException>().having(
            (e) => e.kind,
            'kind',
            BcErrorKind.invalidArgument,
          ),
        ),
      );
    });

    test('the solver kinds keep their kind and fields', () {
      try {
        bc.findZeroAngleShot(_makeShot(), 60000.0);
        fail('expected a BcException');
      } on BcException catch (e) {
        expect(e.kind, BcErrorKind.outOfRange);
        expect(e.requestedDistanceFt, 60000.0);
        expect(e.maxRangeFt, isNotNull);
      }
    });
  });

  group('dense output', () {
    final request = BcTrajectoryRequest(
      rangeLimitFt: 1000.0 * 3.28084,
      rangeStepFt: 100.0 * 3.28084,
      filterFlags: 8, // RANGE
    );

    for (final method in BcIntegrationMethod.values) {
      test('integrateDenseShot, ${method.name}: steps, rows and stats', () {
        final shot = _makeShot(barrelElevationRad: 0.005, method: method);
        final result = bc.integrateDenseShot(shot, request);
        final plain = bc.integrateShot(shot, request);

        // the same integration as integrateShot: the same rows
        expect(result.trajectory.length, plain.trajectory.length);
        expect(result.reason, plain.reason);
        expect(
          result.trajectory.last.distanceFt,
          closeTo(plain.trajectory.last.distanceFt, 1e-6),
        );

        // the accepted steps: time-ordered, from the muzzle to the end
        final steps = result.steps;
        expect(steps.length, greaterThanOrEqualTo(3));
        expect(steps.first.time, 0.0);
        for (var i = 1; i < steps.length; i++) {
          expect(steps[i].time, greaterThan(steps[i - 1].time));
        }
        expect(steps.last.px, greaterThanOrEqualTo(1000.0 * 3.28084 - 1e-6));

        // step statistics for the adaptive methods only
        if (method.isAdaptive) {
          expect(result.stats, isNotNull);
          expect(result.stats!.accepted, greaterThan(0));
          expect(result.stats!.rejected, greaterThanOrEqualTo(0));
        } else {
          expect(result.stats, isNull);
        }
      });
    }

    test('denseGetAt: an exact step, a position, the slant height', () {
      final shot = _makeShot(barrelElevationRad: 0.005);
      final steps = bc.integrateDenseShot(shot, request).steps;

      // an exact step comes back as it is
      final exact = bc.denseGetAt(
        steps,
        BcBaseTrajInterpKey.time,
        steps[2].time,
      );
      expect(exact.px, steps[2].px);
      expect(exact.vy, steps[2].vy);

      // by position: the key is the value asked for
      final x = 500.0 * 3.28084;
      final atX = bc.denseGetAt(steps, BcBaseTrajInterpKey.posX, x);
      expect(atX.px, closeTo(x, 1e-9));
      expect(atX.time, greaterThan(0.0));

      // by slant height: the muzzle is 0.21 m below the sight line, so the bullet crosses it going up
      final up = bc.denseGetAtSlantHeight(steps, 0.0, 0.0);
      expect(up.py, closeTo(0.0, 1e-6));
    });

    test('trajectoryDataFromStep matches the row of the integration', () {
      final shot = _makeShot(barrelElevationRad: 0.005);
      final result = bc.integrateDenseShot(shot, request);
      final rowFt = 300.0 * 3.28084; // 3 x 100 m: one of the requested rows
      final step = bc.denseGetAt(result.steps, BcBaseTrajInterpKey.posX, rowFt);
      final full = bc.trajectoryDataFromStep(shot, step, flag: 8);
      expect(full.flag, 8);
      expect(full.distanceFt, closeTo(rowFt, 1e-6));
      expect(full.time, closeTo(step.time, 1e-12));
      final row = result.trajectory.firstWhere(
        (r) => (r.distanceFt - rowFt).abs() < 1e-3,
      );
      expect(full.heightFt, closeTo(row.heightFt, 0.01));
      expect(full.velocityFps, closeTo(row.velocityFps, 0.5));
    });
  });
}
