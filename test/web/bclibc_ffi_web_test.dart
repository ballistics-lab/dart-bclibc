// WASM/web smoke tests for BcLibCWeb.
//
// Uses the package's own checked-in wasm asset (assets/wasm/), copied into
// this directory mirroring the assets/packages/dart_bclibc/... path Flutter
// web serves it at, so BcLibCWeb.open()'s default scriptUrl resolves the
// same way it would in a real Flutter web app:
//   mkdir -p test/web/assets/packages/dart_bclibc/assets/wasm
//   cp assets/wasm/bclibc_ffi.js assets/wasm/bclibc_ffi.wasm \
//     test/web/assets/packages/dart_bclibc/assets/wasm/
//
// To rebuild assets/wasm/ itself from source: bclibc/build_wasm.sh, then
// cp bclibc/build/web/bclibc_ffi.{js,wasm} assets/wasm/
//
// Then run with:
//   dart test -p chrome test/web/bclibc_ffi_web_test.dart

@TestOn('browser')
library;

import 'package:dart_bclibc/ffi/bclibc_ffi_web.dart';
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
}
