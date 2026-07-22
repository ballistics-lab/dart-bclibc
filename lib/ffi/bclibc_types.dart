// Platform-agnostic value types shared by the native (dart:ffi) and web
// (dart:js_interop against the same C ABI) bclibc backends.
//
// Deliberately has no dart:ffi / dart:io / dart:js_interop imports so it can
// be imported from both bclibc_ffi.dart (native) and bclibc_ffi_web.dart
// (web) without either platform's backend leaking into the other.

// ============================================================================
// Enums (mirror BCLIBCFFI_* C enums; values must match bclibc_ffi.h exactly)
// ============================================================================

enum BcIntegrationMethod {
  rk4(0),
  euler(1);

  final int value;
  const BcIntegrationMethod(this.value);

  static BcIntegrationMethod fromValue(int value) => switch (value) {
    0 => rk4,
    1 => euler,
    _ => throw ArgumentError('Unknown value for BcIntegrationMethod: $value'),
  };
}

enum BcTerminationReason {
  noTerminate(0),
  targetRangeReached(1),
  minimumVelocityReached(2),
  maximumDropReached(3),
  minimumAltitudeReached(4),
  handlerRequestedStop(5);

  final int value;
  const BcTerminationReason(this.value);

  static BcTerminationReason fromValue(int value) => switch (value) {
    0 => noTerminate,
    1 => targetRangeReached,
    2 => minimumVelocityReached,
    3 => maximumDropReached,
    4 => minimumAltitudeReached,
    5 => handlerRequestedStop,
    _ => throw ArgumentError('Unknown value for BcTerminationReason: $value'),
  };
}

/// Interpolation key for [BcBaseTrajData] fields (see [BcLibC.integrateAtShot]-style calls).
enum BcBaseTrajInterpKey {
  time(0),
  mach(1),
  posX(2),
  posY(3),
  posZ(4),
  velX(5),
  velY(6),
  velZ(7);

  final int value;
  const BcBaseTrajInterpKey(this.value);
}

// ============================================================================
// Dart-side value types
// ============================================================================

class BcConfig {
  final double stepMultiplier;
  final double zeroFindingAccuracy;
  final double minimumVelocity;
  final double maximumDrop;
  final int maxIterations;
  final double gravityConstant;
  final double minimumAltitude;

  const BcConfig({
    this.stepMultiplier = 1.0,
    this.zeroFindingAccuracy = 0.001,
    this.minimumVelocity = 50.0,
    this.maximumDrop = -15000.0,
    this.maxIterations = 50,
    this.gravityConstant = -32.17405,
    this.minimumAltitude = -1000.0,
  });
}

class BcWind {
  final double velocityFps;
  final double directionFromRad;
  final double untilDistanceFt;
  final double maxDistanceFt;

  const BcWind({
    required this.velocityFps,
    required this.directionFromRad,
    this.untilDistanceFt = 1e9,
    this.maxDistanceFt = 1e9,
  });
}

class BcDragPoint {
  final double mach;
  final double cd;
  const BcDragPoint(this.mach, this.cd);
}

/// Shot descriptor in natural units.
///
/// All physics conversions (atmosphere density, Coriolis trig, PCHIP drag
/// curve, cant sin/cos) are performed inside C++ by BCLIBC_Shot::to_shot_props().
///
/// [latitudeDeg] / [azimuthDeg]: pass double.nan to disable Coriolis (flat-fire only).
/// [pressureHpa] == 0: vacuum (zero drag).
class BcShot {
  final double bc;
  final double weightGrain;
  final double diameterInch;
  final double lengthInch;
  final double muzzleVelocityFps;
  final double sightHeightFt;
  final double twistInch;

  final double tempC;
  final double pressureHpa;
  final double altitudeFt;
  final double humidity;

  final List<BcDragPoint> dragTable;
  final List<BcWind> winds;

  final double lookAngleRad;
  final double barrelElevationRad;
  final double barrelAzimuthRad;
  final double cantAngleRad;

  final double latitudeDeg;
  final double azimuthDeg;

  final BcConfig config;
  final BcIntegrationMethod method;

  const BcShot({
    required this.bc,
    required this.weightGrain,
    required this.diameterInch,
    required this.lengthInch,
    required this.muzzleVelocityFps,
    required this.sightHeightFt,
    required this.twistInch,
    required this.tempC,
    required this.pressureHpa,
    required this.altitudeFt,
    this.humidity = 0.0,
    required this.dragTable,
    this.winds = const [],
    required this.lookAngleRad,
    required this.barrelElevationRad,
    this.barrelAzimuthRad = 0.0,
    this.cantAngleRad = 0.0,
    this.latitudeDeg = double.nan,
    this.azimuthDeg = double.nan,
    this.config = const BcConfig(),
    this.method = BcIntegrationMethod.rk4,
  });
}

class BcTrajectoryRequest {
  final double rangeLimitFt;
  final double rangeStepFt;
  final double timeStep;

  /// BCLIBCFFI_TrajFlag bitmask (may combine multiple flags via bitwise OR)
  final int filterFlags;

  const BcTrajectoryRequest({
    required this.rangeLimitFt,
    required this.rangeStepFt,
    this.timeStep = 0.0,
    this.filterFlags = 8, // BCLIBCFFI_TrajFlag.BCLIBCFFI_TRAJ_FLAG_RANGE
  });
}

// ============================================================================
// Result types
// ============================================================================

class BcTrajectoryData {
  final double time, distanceFt, velocityFps, mach;
  final double heightFt, slantHeightFt, dropAngleRad;
  final double windageFt, windageAngleRad;
  final double slantDistanceFt, angleRad;
  final double densityRatio, drag;
  final double energyFtLb, ogwLb;
  final int flag; // BCLIBCFFI_TrajFlag

  const BcTrajectoryData({
    required this.time,
    required this.distanceFt,
    required this.velocityFps,
    required this.mach,
    required this.heightFt,
    required this.slantHeightFt,
    required this.dropAngleRad,
    required this.windageFt,
    required this.windageAngleRad,
    required this.slantDistanceFt,
    required this.angleRad,
    required this.densityRatio,
    required this.drag,
    required this.energyFtLb,
    required this.ogwLb,
    required this.flag,
  });
}

class BcBaseTrajData {
  final double time, px, py, pz, vx, vy, vz, mach;
  const BcBaseTrajData({
    required this.time,
    required this.px,
    required this.py,
    required this.pz,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.mach,
  });
}

class BcMaxRangeResult {
  final double maxRangeFt;
  final double angleAtMaxRad;
  const BcMaxRangeResult(this.maxRangeFt, this.angleAtMaxRad);
}

class BcHitResult {
  final List<BcTrajectoryData> trajectory;
  final BcTerminationReason reason;
  const BcHitResult(this.trajectory, this.reason);
}

class BcInterception {
  final BcBaseTrajData rawData;
  final BcTrajectoryData fullData;
  const BcInterception(this.rawData, this.fullData);
}

// ============================================================================
// Exception
// ============================================================================

// ============================================================================
// Engine contract
//
// Implemented by BcLibC (native, dart:ffi) and BcLibCWeb (web,
// dart:js_interop against the same BCLIBCFFI_* C ABI compiled to wasm), so
// Calculator's conversion logic can run unmodified against either backend.
// ============================================================================

abstract class BcEngine {
  double getCorrection(double distanceFt, double offsetFt);
  double calculateEnergy(double bulletWeightGrain, double velocityFps);
  double calculateOgw(double bulletWeightGrain, double velocityFps);

  BcTrajectoryData findApexShot(BcShot shot);
  BcMaxRangeResult findMaxRangeShot(
    BcShot shot, {
    double lowAngleDeg,
    double highAngleDeg,
  });
  double findZeroAngleShot(BcShot shot, double distanceFt);
  BcHitResult integrateShot(BcShot shot, BcTrajectoryRequest request);
  BcInterception integrateAtShot(
    BcShot shot,
    BcBaseTrajInterpKey key,
    double targetValue,
  );
}

class BcException implements Exception {
  final int code; // BCLIBCFFI_Status
  final String message;
  // OutOfRange extras
  final double? requestedDistanceFt, maxRangeFt, lookAngleRad;
  // ZeroFinding extras
  final double? zeroFindingError, lastBarrelElevationRad;
  final int? iterationsCount;

  const BcException({
    required this.code,
    required this.message,
    this.requestedDistanceFt,
    this.maxRangeFt,
    this.lookAngleRad,
    this.zeroFindingError,
    this.lastBarrelElevationRad,
    this.iterationsCount,
  });

  @override
  String toString() => 'BcException($code): $message';
}
