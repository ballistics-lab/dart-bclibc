// Platform-agnostic Calculator conversion logic, shared by:
//   - Calculator (native, calculator.dart) — delegates its methods here.
//   - AsyncCalculator's web engine (async_engine_web.dart) — calls these
//     directly against a BcLibCWeb, without going through the Calculator
//     class at all (which lives in a dart:ffi-importing file and so can't
//     be compiled for web).
//
// Kept free of dart:ffi/dart:io/js_interop imports for exactly that reason.

import 'package:bclibc/ffi/bclibc_types.dart';
import 'package:bclibc/src/conditions.dart';
import 'package:bclibc/src/shot.dart';
import 'package:bclibc/src/trajectory_data.dart';
import 'package:bclibc/src/unit.dart';

double _toFeet(Distance d) => d.in_(Unit.foot);

/// Thin field mapper: copies [Shot] fields into [BcShot].
/// All physics/unit conversions (atmosphere density, Coriolis trig, PCHIP
/// drag curve, cant sin/cos) are performed inside C++ via
/// BCLIBC_Shot::to_shot_props().
BcShot toBcShot(Shot shot, BcIntegrationMethod method, BcConfig config) {
  final mvFps = shot.ammo
      .getVelocityForTemp(shot.atmo.powderTemp)
      .in_(Unit.fps);

  return BcShot(
    bc: shot.ammo.dm.bc,
    weightGrain: shot.ammo.dm.weight.in_(Unit.grain),
    diameterInch: shot.ammo.dm.diameter.in_(Unit.inch),
    lengthInch: shot.ammo.dm.length.in_(Unit.inch),
    muzzleVelocityFps: mvFps,
    sightHeightFt: shot.weapon.sightHeight.in_(Unit.foot),
    twistInch: shot.weapon.twist.in_(Unit.inch),
    tempC: shot.atmo.temperature.in_(Unit.celsius),
    pressureHpa: shot.atmo.pressure.in_(Unit.hPa),
    altitudeFt: shot.atmo.altitude.in_(Unit.foot),
    humidity: shot.atmo.humidity,
    dragTable: shot.ammo.dm.dragTable
        .map((p) => BcDragPoint(p.mach, p.cd))
        .toList(),
    winds: shot.winds.map(_toBcWind).toList(),
    lookAngleRad: shot.lookAngle.in_(Unit.radian),
    barrelElevationRad: shot.barrelElevation.in_(Unit.radian),
    barrelAzimuthRad: shot.barrelAzimuth.in_(Unit.radian),
    cantAngleRad: shot.cantAngle.in_(Unit.radian),
    latitudeDeg: shot.latitudeDeg ?? double.nan,
    azimuthDeg: shot.azimuthDeg ?? double.nan,
    config: config,
    method: method,
  );
}

BcWind _toBcWind(Wind w) => BcWind(
  velocityFps: w.velocity.in_(Unit.fps),
  directionFromRad: w.directionFrom.in_(Unit.radian),
  untilDistanceFt: w.untilDistance.in_(Unit.foot),
  maxDistanceFt: Wind.maxDistanceFeet,
);

TrajectoryData toTrajectoryData(BcTrajectoryData d) => TrajectoryData(
  time: d.time,
  distance: Distance(d.distanceFt, Unit.foot),
  velocity: Velocity(d.velocityFps, Unit.fps),
  mach: d.mach,
  height: Distance(d.heightFt, Unit.foot),
  slantHeight: Distance(d.slantHeightFt, Unit.foot),
  dropAngle: Angular(d.dropAngleRad, Unit.radian),
  windage: Distance(d.windageFt, Unit.foot),
  windageAngle: Angular(d.windageAngleRad, Unit.radian),
  slantDistance: Distance(d.slantDistanceFt, Unit.foot),
  angle: Angular(d.angleRad, Unit.radian),
  densityRatio: d.densityRatio,
  drag: d.drag,
  energy: Energy(d.energyFtLb, Unit.footPound),
  ogw: Weight(d.ogwLb, Unit.pound),
  flag: d.flag,
);

/// The row as the engine takes it (the inverse of [toTrajectoryData]).
BcTrajectoryData toBcTrajectoryData(TrajectoryData d) => BcTrajectoryData(
  time: d.time,
  distanceFt: d.distance.in_(Unit.foot),
  velocityFps: d.velocity.in_(Unit.fps),
  mach: d.mach,
  heightFt: d.height.in_(Unit.foot),
  slantHeightFt: d.slantHeight.in_(Unit.foot),
  dropAngleRad: d.dropAngle.in_(Unit.radian),
  windageFt: d.windage.in_(Unit.foot),
  windageAngleRad: d.windageAngle.in_(Unit.radian),
  slantDistanceFt: d.slantDistance.in_(Unit.foot),
  angleRad: d.angle.in_(Unit.radian),
  densityRatio: d.densityRatio,
  drag: d.drag,
  energyFtLb: d.energy.in_(Unit.footPound),
  ogwLb: d.ogw.in_(Unit.pound),
  flag: d.flag,
);

/// Returns the barrel elevation (relative to look-angle) needed to hit
/// a target at [targetDistance].
Angular calcBarrelElevationForTarget(
  BcEngine engine,
  BcIntegrationMethod method,
  BcConfig config,
  Shot shot,
  Distance targetDistance,
) {
  final distFt = _toFeet(targetDistance);
  final bcShot = toBcShot(shot, method, config);
  final totalRad = engine.findZeroAngleShot(bcShot, distFt);
  return Angular(totalRad - shot.lookAngle.in_(Unit.radian), Unit.radian);
}

/// Calculates the holdover, windage, and trajectory point for [targetDistance].
(Angular, Angular, TrajectoryData) calcAimingSolutionForTarget(
  BcEngine engine,
  BcIntegrationMethod method,
  BcConfig config,
  Shot shot,
  Distance targetDistance,
) {
  final result = engine.findZeroPointShot(
    toBcShot(shot, method, config),
    _toFeet(targetDistance),
  );
  final targetZeroElevation = Angular(
    result.angleRad - shot.lookAngle.in_(Unit.radian),
    Unit.radian,
  );
  final verticalHold = Angular(
    targetZeroElevation.in_(Unit.radian) -
        shot.weapon.zeroElevation.in_(Unit.radian),
    Unit.radian,
  );
  return (
    verticalHold,
    Angular(result.point.windageAngleRad, Unit.radian),
    toTrajectoryData(result.point),
  );
}

/// Fires a shot and returns the full trajectory as a [HitResult].
///
/// [trajectoryRange] and [trajectoryStep] accept a [Distance] object or
/// a raw number in the preferred distance unit.
///
/// With [denseOutput] the result also carries the accepted steps of the integrator ([HitResult.denseSteps]), which
/// [calcGetAt] and [calcGetAtDistance] interpolate in; the adaptive methods run at [relativeTolerance] and
/// [absoluteTolerance] (the fixed-step ones ignore them).
HitResult calcFire(
  BcEngine engine,
  BcIntegrationMethod method,
  BcConfig config, {
  required Shot shot,
  required Distance trajectoryRange,
  Distance? trajectoryStep,
  double timeStep = 0.0,
  int filterFlags = 8, // BCLIBCFFI_TrajFlag.BCLIBCFFI_TRAJ_FLAG_RANGE
  bool raiseRangeError = true,
  bool denseOutput = false,
  double relativeTolerance = 1e-6,
  double absoluteTolerance = 1e-6,
}) {
  final rangeFt = _toFeet(trajectoryRange);
  final stepFt = trajectoryStep != null ? _toFeet(trajectoryStep) : rangeFt;

  final request = BcTrajectoryRequest(
    rangeLimitFt: rangeFt,
    rangeStepFt: stepFt,
    timeStep: timeStep,
    filterFlags: filterFlags,
  );

  late List<BcTrajectoryData> rows;
  List<BcBaseTrajData>? steps;
  try {
    final bcShot = toBcShot(shot, method, config);
    if (denseOutput) {
      final dense = engine.integrateDenseShot(
        bcShot,
        request,
        relativeTolerance: relativeTolerance,
        absoluteTolerance: absoluteTolerance,
      );
      rows = dense.trajectory;
      steps = dense.steps;
    } else {
      rows = engine.integrateShot(bcShot, request).trajectory;
    }
  } on BcException catch (e) {
    if (raiseRangeError) rethrow;
    return HitResult(shot, [], filterFlags: filterFlags, error: e);
  }

  return HitResult(
    shot,
    rows.map(toTrajectoryData).toList(),
    filterFlags: filterFlags,
    denseSteps: steps,
  );
}

/// The point of the trajectory where [key] reaches [value], interpolated in the dense output of [hit] (it must have been
/// fired with `denseOutput: true`, else a [StateError]) and turned into a full record with the atmosphere, drag and Coriolis
/// data of its shot. [startFromTime] limits the search to steps at or after it (ignored for [BcBaseTrajInterpKey.time]);
/// [flag] is the `TrajFlag` value stored in the record. A value the trajectory does not reach is a [BcException] of kind
/// [BcErrorKind.outOfBounds].
TrajectoryData calcGetAt(
  BcEngine engine,
  BcIntegrationMethod method,
  BcConfig config,
  HitResult hit,
  BcBaseTrajInterpKey key,
  double value, {
  double startFromTime = 0.0,
  int flag = 0,
}) {
  final steps = hit.denseSteps;
  if (steps == null || steps.isEmpty) {
    throw StateError(
      'The HitResult has no dense output: fire the shot with denseOutput: true.',
    );
  }
  final step = engine.denseGetAt(
    steps,
    key,
    value,
    startFromTime: startFromTime,
  );
  return toTrajectoryData(
    engine.trajectoryDataFromStep(
      toBcShot(hit.shot, method, config),
      step,
      flag: flag,
    ),
  );
}

/// The point of the trajectory at [distance] (downrange), interpolated: in the dense output of [hit] when it has one,
/// else between its rows (three-point PCHIP through the rows around it, by the library). A distance before the first
/// row or beyond the last is a [RangeError]; a [HitResult] with fewer than 3 rows and no dense output, a [StateError].
TrajectoryData calcGetAtDistance(
  BcEngine engine,
  BcIntegrationMethod method,
  BcConfig config,
  HitResult hit,
  Distance distance,
) {
  final targetFt = _toFeet(distance);
  final steps = hit.denseSteps;
  if (steps != null && steps.isNotEmpty) {
    return calcGetAt(
      engine,
      method,
      config,
      hit,
      BcBaseTrajInterpKey.posX,
      targetFt,
    );
  }

  // the rows by distance, without the ones at the same distance as the one before (an event row on a range row)
  final rows = <TrajectoryData>[];
  for (final r in hit.records) {
    if (rows.isEmpty || _toFeet(r.distance) > _toFeet(rows.last.distance)) {
      rows.add(r);
    }
  }
  if (rows.length < 3) {
    throw StateError(
      'Interpolating between the rows needs at least 3 of them (or fire with denseOutput: true).',
    );
  }
  final firstFt = _toFeet(rows.first.distance);
  final lastFt = _toFeet(rows.last.distance);
  if (targetFt < firstFt - 1e-9 || targetFt > lastFt + 1e-9) {
    throw RangeError(
      'The distance ($targetFt ft) is outside the trajectory ($firstFt .. $lastFt ft).',
    );
  }
  var right = rows.indexWhere((r) => _toFeet(r.distance) >= targetFt);
  // a row at the distance (to a billionth of a foot, as get_at in py-ballisticcalc) is returned as it is
  if ((_toFeet(rows[right].distance) - targetFt).abs() < 1e-9) {
    return rows[right];
  }
  // the three rows around the target: the one before, the first beyond it and the next, or the last three
  var left = right - 1;
  if (left > rows.length - 3) {
    left = rows.length - 3;
  }
  right = left + 2;
  return toTrajectoryData(
    engine.interpolateTrajectoryData(
      BcTrajectoryInterpKey.distance,
      targetFt,
      toBcTrajectoryData(rows[left]),
      toBcTrajectoryData(rows[left + 1]),
      toBcTrajectoryData(rows[right]),
    ),
  );
}
