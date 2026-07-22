// Platform-agnostic Calculator conversion logic, shared by:
//   - Calculator (native, calculator.dart) — delegates its methods here.
//   - AsyncCalculator's web engine (async_engine_web.dart) — calls these
//     directly against a BcLibCWeb, without going through the Calculator
//     class at all (which lives in a dart:ffi-importing file and so can't
//     be compiled for web).
//
// Kept free of dart:ffi/dart:io/js_interop imports for exactly that reason.

import 'package:dart_bclibc/ffi/bclibc_types.dart';
import 'package:dart_bclibc/src/conditions.dart';
import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';

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

/// Fires a shot and returns the full trajectory as a [HitResult].
///
/// [trajectoryRange] and [trajectoryStep] accept a [Distance] object or
/// a raw number in the preferred distance unit.
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
}) {
  final rangeFt = _toFeet(trajectoryRange);
  final stepFt = trajectoryStep != null ? _toFeet(trajectoryStep) : rangeFt;

  final request = BcTrajectoryRequest(
    rangeLimitFt: rangeFt,
    rangeStepFt: stepFt,
    timeStep: timeStep,
    filterFlags: filterFlags,
  );

  late BcHitResult bcResult;
  try {
    bcResult = engine.integrateShot(toBcShot(shot, method, config), request);
  } on BcException catch (e) {
    if (raiseRangeError) rethrow;
    return HitResult(shot, [], filterFlags: filterFlags, error: e);
  }

  final traj = bcResult.trajectory.map(toTrajectoryData).toList();
  return HitResult(shot, traj, filterFlags: filterFlags);
}
