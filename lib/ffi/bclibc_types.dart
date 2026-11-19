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
  euler(1),
  velocityVerlet(2),
  rkck(3),
  dopri(4),
  tsitouras(5);

  final int value;
  const BcIntegrationMethod(this.value);

  /// The embedded Runge-Kutta methods with step-size control (they take tolerances, see
  /// [BcEngine.integrateDenseShot]); the others have a fixed step.
  bool get isAdaptive => this == rkck || this == dopri || this == tsitouras;

  static BcIntegrationMethod fromValue(int value) => switch (value) {
    0 => rk4,
    1 => euler,
    2 => velocityVerlet,
    3 => rkck,
    4 => dopri,
    5 => tsitouras,
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

/// The field of a [BcTrajectoryData] row that is the independent variable of [BcEngine.interpolateTrajectoryData]
/// (`BCLIBCFFI_TrajectoryInterpKey`).
enum BcTrajectoryInterpKey {
  time(0),
  distance(1),
  velocity(2),
  mach(3),
  height(4),
  slantHeight(5),
  dropAngle(6),
  windage(7),
  windageAngle(8),
  slantDistance(9),
  angle(10),
  densityRatio(11),
  drag(12),
  energy(13),
  ogw(14),
  flag(15);

  final int value;
  const BcTrajectoryInterpKey(this.value);
}

/// `BCLIBCFFI_InterpMethod`.
enum BcInterpMethod {
  pchip(0),
  linear(1);

  final int value;
  const BcInterpMethod(this.value);
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

/// Result of a lower-arc zero solve, including the point at the requested
/// target range.
class BcZeroPointResult {
  final double angleRad;
  final BcTrajectoryData point;
  const BcZeroPointResult(this.angleRad, this.point);
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

/// Accepted and rejected steps of an adaptive integration (`BCLIBCFFI_StepStats`).
class BcStepStats {
  final int accepted, rejected;
  const BcStepStats(this.accepted, this.rejected);
}

/// What [BcEngine.integrateDenseShot] returns: the filtered rows of [BcHitResult] and the accepted steps of the
/// integrator (dense output), in time order. [stats] is set for the adaptive methods only.
class BcDenseResult {
  final List<BcTrajectoryData> trajectory;
  final BcTerminationReason reason;
  final List<BcBaseTrajData> steps;
  final BcStepStats? stats;
  const BcDenseResult(this.trajectory, this.reason, this.steps, this.stats);
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
  BcZeroPointResult findZeroPointShot(BcShot shot, double distanceFt);
  BcHitResult integrateShot(BcShot shot, BcTrajectoryRequest request);
  BcInterception integrateAtShot(
    BcShot shot,
    BcBaseTrajInterpKey key,
    double targetValue,
  );

  /// [integrateShot] that also returns the accepted steps of the integrator (dense output), for any method: the
  /// fixed-step ones through `BCLIBCFFI_integrate_dense_shot`, the adaptive ones through `BCLIBCFFI_integrate_adaptive_shot`
  /// with [relativeTolerance] (finite, positive) and [absoluteTolerance] (finite, non-negative); a tolerance out of range
  /// is a [BcException] of kind [BcErrorKind.invalidArgument]. The tolerances are ignored by the fixed-step methods.
  BcDenseResult integrateDenseShot(
    BcShot shot,
    BcTrajectoryRequest request, {
    double relativeTolerance,
    double absoluteTolerance,
  });

  /// The step where [key] reaches [value], interpolated in dense output ([steps], time-ordered: what
  /// [integrateDenseShot] returned), or the exact step when one matches. Only steps with time >= [startFromTime] are
  /// searched (0 or negative: all; ignored for [BcBaseTrajInterpKey.time]). A value beyond the stream is a
  /// [BcErrorKind.outOfBounds] error with the range of the stream; fewer than 3 steps, [BcErrorKind.domain].
  BcBaseTrajData denseGetAt(
    List<BcBaseTrajData> steps,
    BcBaseTrajInterpKey key,
    double value, {
    double startFromTime,
  });

  /// The step where the height above the line of sight at [lookAngleRad] reaches [value].
  BcBaseTrajData denseGetAtSlantHeight(
    List<BcBaseTrajData> steps,
    double lookAngleRad,
    double value,
  );

  /// The row where [key] has the value [value], interpolated from three rows ([t0], [t1], [t2], ordered by the key:
  /// what [BcDenseResult.trajectory] and [BcHitResult.trajectory] hold). Every field is interpolated, the key field is
  /// set to [value] and [flag] is the flag of the result. Two rows with the same key is a [BcErrorKind.domain] error.
  BcTrajectoryData interpolateTrajectoryData(
    BcTrajectoryInterpKey key,
    double value,
    BcTrajectoryData t0,
    BcTrajectoryData t1,
    BcTrajectoryData t2, {
    int flag,
    BcInterpMethod method,
  });

  /// The full record (distance, drop, windage, energy, ...) of one dense [step], with the atmosphere, drag and Coriolis
  /// data of [shot]; [flag] is the `BCLIBCFFI_TrajFlag` value stored in it.
  BcTrajectoryData trajectoryDataFromStep(
    BcShot shot,
    BcBaseTrajData step, {
    int flag,
  });
}

/// The kinds of failure of a call into bclibc: `BCLIBCFFI_Status` (bclibc 2.2 tells them all apart; before, everything that
/// was not a solver's was [generic]).
enum BcErrorKind {
  solverRuntime(1),
  outOfRange(2),
  zeroFinding(3),
  interception(4),
  generic(5),

  /// Inputs the operation cannot work with: a degenerate interpolation segment, too few points ([BcException.lhs], [BcException.rhs]).
  domain(6),

  /// An argument that is not acceptable: a drag table of fewer than 2 points, a tolerance out of range, an unknown key.
  invalidArgument(7),

  /// An index or a value outside the data: a key beyond the trajectory ([BcException.requestedValue],
  /// [BcException.minimumValue], [BcException.maximumValue]).
  outOfBounds(8),
  logic(9),
  runtime(10),

  /// A status code this package does not know (a library newer than the bindings).
  unknown(-1);

  final int code;
  const BcErrorKind(this.code);

  static BcErrorKind fromCode(int code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return unknown;
  }
}

class BcException implements Exception {
  final int code; // BCLIBCFFI_Status
  final String message;
  // OutOfRange extras
  final double? requestedDistanceFt, maxRangeFt, lookAngleRad;
  // ZeroFinding extras
  final double? zeroFindingError, lastBarrelElevationRad;
  final int? iterationsCount;
  // OutOfBounds extras: the value or index asked for and the range the data allows
  final double? requestedValue, minimumValue, maximumValue;
  // Domain extras: the two values the operation could not tell apart or work with
  final double? lhs, rhs;

  const BcException({
    required this.code,
    required this.message,
    this.requestedDistanceFt,
    this.maxRangeFt,
    this.lookAngleRad,
    this.zeroFindingError,
    this.lastBarrelElevationRad,
    this.iterationsCount,
    this.requestedValue,
    this.minimumValue,
    this.maximumValue,
    this.lhs,
    this.rhs,
  });

  /// The exception of a failed call, from the fields of `BCLIBCFFI_Error` (what `f64_0`..`f64_2` and `i32_0` mean
  /// depends on the code, see the table at `BCLIBCFFI_Error` in bclibc_ffi.h): shared by the native and the web
  /// backend, so both throw the same thing for the same failure.
  factory BcException.fromStatus({
    required int code,
    required String message,
    required double f64_0,
    required double f64_1,
    required double f64_2,
    required int i32_0,
  }) => switch (BcErrorKind.fromCode(code)) {
    BcErrorKind.outOfRange => BcException(
      code: code,
      message: message,
      requestedDistanceFt: f64_0,
      maxRangeFt: f64_1,
      lookAngleRad: f64_2,
    ),
    BcErrorKind.zeroFinding => BcException(
      code: code,
      message: message,
      zeroFindingError: f64_0,
      lastBarrelElevationRad: f64_1,
      iterationsCount: i32_0,
    ),
    BcErrorKind.outOfBounds => BcException(
      code: code,
      message: message,
      requestedValue: f64_0,
      minimumValue: f64_1,
      maximumValue: f64_2,
    ),
    BcErrorKind.domain => BcException(
      code: code,
      message: message,
      lhs: f64_0,
      rhs: f64_1,
    ),
    _ => BcException(code: code, message: message),
  };

  BcErrorKind get kind => BcErrorKind.fromCode(code);

  @override
  String toString() => 'BcException($code): $message';
}
