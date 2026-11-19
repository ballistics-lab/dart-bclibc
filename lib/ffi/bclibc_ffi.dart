// ignore_for_file: dangling_library_doc_comments
/// Thin Dart wrapper over the bclibc C FFI layer.
///
/// API:
///   findApexShot, findMaxRangeShot, findZeroAngleShot, integrateShot, integrateAtShot,
///   integrateDenseShot, denseGetAt, denseGetAtSlantHeight, trajectoryDataFromStep
///
/// Usage:
///   final bc = BcLibC.open();
///   final hit = bc.integrateShot(shot, request);

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'bclibc_bindings.g.dart';
import 'bclibc_types.dart';

export 'bclibc_types.dart';

// ffi.Array<ffi.Char> → Dart String (null-terminated)
String _charArrayToString(ffi.Array<ffi.Char> arr, int maxLen) {
  final codes = <int>[];
  for (var i = 0; i < maxLen; i++) {
    final c = arr[i];
    if (c == 0) break;
    codes.add(c);
  }
  return String.fromCharCodes(codes);
}

Never _throwFromError(BCLIBCFFI_Error err) => throw BcException.fromStatus(
  code: err.code,
  message: _charArrayToString(err.message, 512),
  f64_0: err.f64_0,
  f64_1: err.f64_1,
  f64_2: err.f64_2,
  i32_0: err.i32_0,
);

BcTrajectoryData _trajDataFromNative(BCLIBCFFI_TrajectoryData s) =>
    BcTrajectoryData(
      time: s.time,
      distanceFt: s.distance_ft,
      velocityFps: s.velocity_fps,
      mach: s.mach,
      heightFt: s.height_ft,
      slantHeightFt: s.slant_height_ft,
      dropAngleRad: s.drop_angle_rad,
      windageFt: s.windage_ft,
      windageAngleRad: s.windage_angle_rad,
      slantDistanceFt: s.slant_distance_ft,
      angleRad: s.angle_rad,
      densityRatio: s.density_ratio,
      drag: s.drag,
      energyFtLb: s.energy_ft_lb,
      ogwLb: s.ogw_lb,
      flag: s.flag,
    );

BcBaseTrajData _baseTrajFromNative(BCLIBCFFI_BaseTrajData s) => BcBaseTrajData(
  time: s.time,
  px: s.px,
  py: s.py,
  pz: s.pz,
  vx: s.vx,
  vy: s.vy,
  vz: s.vz,
  mach: s.mach,
);

// ============================================================================
// Native struct fill helper
// ============================================================================

extension _FillNativeShot on BcShot {
  void _fill(BCLIBCFFI_Shot p, Arena arena) {
    p.bc = bc;
    p.weight_grain = weightGrain;
    p.diameter_inch = diameterInch;
    p.length_inch = lengthInch;
    p.muzzle_velocity_fps = muzzleVelocityFps;
    p.sight_height_ft = sightHeightFt;
    p.twist_inch = twistInch;
    p.temp_c = tempC;
    p.pressure_hpa = pressureHpa;
    p.altitude_ft = altitudeFt;
    p.humidity = humidity;
    p.look_angle_rad = lookAngleRad;
    p.barrel_elevation_rad = barrelElevationRad;
    p.barrel_azimuth_rad = barrelAzimuthRad;
    p.cant_angle_rad = cantAngleRad;
    p.latitude_deg = latitudeDeg;
    p.azimuth_deg = azimuthDeg;
    p.methodAsInt = method.value;

    p.config.cStepMultiplier = config.stepMultiplier;
    p.config.cZeroFindingAccuracy = config.zeroFindingAccuracy;
    p.config.cMinimumVelocity = config.minimumVelocity;
    p.config.cMaximumDrop = config.maximumDrop;
    p.config.cMaxIterations = config.maxIterations;
    p.config.cGravityConstant = config.gravityConstant;
    p.config.cMinimumAltitude = config.minimumAltitude;

    if (dragTable.isEmpty) {
      p.mach_data = ffi.nullptr;
      p.cd_data = ffi.nullptr;
      p.drag_table_size = 0;
    } else {
      final mach = arena<ffi.Double>(dragTable.length);
      final cd = arena<ffi.Double>(dragTable.length);
      for (var i = 0; i < dragTable.length; i++) {
        mach[i] = dragTable[i].mach;
        cd[i] = dragTable[i].cd;
      }
      p.mach_data = mach;
      p.cd_data = cd;
      p.drag_table_size = dragTable.length;
    }

    if (winds.isEmpty) {
      p.winds = ffi.nullptr;
      p.wind_count = 0;
    } else {
      final ws = arena<BCLIBCFFI_Wind>(winds.length);
      for (var i = 0; i < winds.length; i++) {
        ws[i].velocity_fps = winds[i].velocityFps;
        ws[i].direction_from_rad = winds[i].directionFromRad;
        ws[i].until_distance_ft = winds[i].untilDistanceFt;
        ws[i].max_distance_ft = winds[i].maxDistanceFt;
      }
      p.winds = ws;
      p.wind_count = winds.length;
    }
  }
}

void _fillRequest(BCLIBCFFI_TrajectoryRequest r, BcTrajectoryRequest request) {
  r.range_limit_ft = request.rangeLimitFt;
  r.range_step_ft = request.rangeStepFt;
  r.time_step = request.timeStep;
  r.filter_flags = request.filterFlags;
}

void _fillBaseTraj(BCLIBCFFI_BaseTrajData d, BcBaseTrajData s) {
  d.time = s.time;
  d.px = s.px;
  d.py = s.py;
  d.pz = s.pz;
  d.vx = s.vx;
  d.vy = s.vy;
  d.vz = s.vz;
  d.mach = s.mach;
}

/// The steps as a C array in the [arena]; NULL for none (the library answers an empty stream itself).
ffi.Pointer<BCLIBCFFI_BaseTrajData> _stepsToNative(
  List<BcBaseTrajData> steps,
  Arena arena,
) {
  if (steps.isEmpty) return ffi.nullptr;
  final a = arena<BCLIBCFFI_BaseTrajData>(steps.length);
  for (var i = 0; i < steps.length; i++) {
    _fillBaseTraj(a[i], steps[i]);
  }
  return a;
}

// ============================================================================
// Main API class
// ============================================================================

class BcLibC implements BcEngine {
  BcLibC._();

  /// Opens the native library and checks that it is usable. Call once per
  /// isolate.
  ///
  /// The `@Native` bindings resolve the library lazily, on the first call into
  /// it, so a missing or unloadable `libbclibc_ffi` would otherwise only show
  /// up later, as an `ArgumentError` out of the first calculation. This calls
  /// one trivial native function right away so that the failure happens here,
  /// where callers (and startup checks) expect it.
  ///
  /// Throws a [StateError] if the library cannot be loaded.
  factory BcLibC.open() {
    try {
      BCLIBCFFI_get_version();
    } on Object catch (e) {
      throw StateError(
        'Could not load the native bclibc library (libbclibc_ffi): $e',
      );
    }
    return BcLibC._();
  }

  // ── Utility functions ──────────────────────────────────────────────────────

  @override
  double getCorrection(double distanceFt, double offsetFt) =>
      BCLIBCFFI_get_correction(distanceFt, offsetFt);

  @override
  double calculateEnergy(double bulletWeightGrain, double velocityFps) =>
      BCLIBCFFI_calculate_energy(bulletWeightGrain, velocityFps);

  @override
  double calculateOgw(double bulletWeightGrain, double velocityFps) =>
      BCLIBCFFI_calculate_ogw(bulletWeightGrain, velocityFps);

  // ── BcShot-based API (all physics conversion in C++) ──────────────────────

  @override
  BcTrajectoryData findApexShot(BcShot shot) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final out = arena<BCLIBCFFI_TrajectoryData>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    final st = BCLIBCFFI_find_apex_shot(p, out, err);
    if (st != 0) _throwFromError(err.ref);
    return _trajDataFromNative(out.ref);
  });

  @override
  BcMaxRangeResult findMaxRangeShot(
    BcShot shot, {
    double lowAngleDeg = 0.0,
    double highAngleDeg = 45.0,
  }) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final out = arena<BCLIBCFFI_MaxRangeResult>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    final st = BCLIBCFFI_find_max_range_shot(
      p,
      lowAngleDeg,
      highAngleDeg,
      out,
      err,
    );
    if (st != 0) _throwFromError(err.ref);
    return BcMaxRangeResult(out.ref.max_range_ft, out.ref.angle_at_max_rad);
  });

  @override
  double findZeroAngleShot(BcShot shot, double distanceFt) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final outAngle = arena<ffi.Double>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    final st = BCLIBCFFI_find_zero_angle_shot(p, distanceFt, outAngle, err);
    if (st != 0) _throwFromError(err.ref);
    return outAngle.value;
  });

  @override
  BcZeroPointResult findZeroPointShot(BcShot shot, double distanceFt) =>
      using((arena) {
        final p = arena<BCLIBCFFI_Shot>();
        final out = arena<BCLIBCFFI_ZeroPointResult>();
        final err = arena<BCLIBCFFI_Error>();
        shot._fill(p.ref, arena);
        final st = BCLIBCFFI_find_zero_point_shot(p, distanceFt, out, err);
        if (st != 0) _throwFromError(err.ref);
        return BcZeroPointResult(
          out.ref.angle_rad,
          _trajDataFromNative(out.ref.point),
        );
      });

  @override
  BcHitResult integrateShot(BcShot shot, BcTrajectoryRequest request) => using((
    arena,
  ) {
    final p = arena<BCLIBCFFI_Shot>();
    final req = arena<BCLIBCFFI_TrajectoryRequest>();
    final pPtr = arena<ffi.Pointer<BCLIBCFFI_TrajectoryData>>();
    final pCount = arena<ffi.Int32>();
    final pReason = arena<ffi.Int32>();
    final err = arena<BCLIBCFFI_Error>();

    shot._fill(p.ref, arena);
    _fillRequest(req.ref, request);

    final st = BCLIBCFFI_integrate_shot(p, req, pPtr, pCount, pReason, err);
    if (st != 0) _throwFromError(err.ref);

    final count = pCount.value;
    final rawPtr = pPtr.value;
    try {
      final records = List<BcTrajectoryData>.generate(
        count,
        (i) => _trajDataFromNative(rawPtr[i]),
      );
      return BcHitResult(records, BcTerminationReason.fromValue(pReason.value));
    } finally {
      if (count > 0) BCLIBCFFI_free_trajectory(rawPtr);
    }
  });

  @override
  BcInterception integrateAtShot(
    BcShot shot,
    BcBaseTrajInterpKey key,
    double targetValue,
  ) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final out = arena<BCLIBCFFI_Interception>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    final st = BCLIBCFFI_integrate_at_shot(p, key.value, targetValue, out, err);
    if (st != 0) _throwFromError(err.ref);
    return BcInterception(
      _baseTrajFromNative(out.ref.raw_data),
      _trajDataFromNative(out.ref.full_data),
    );
  });

  // ── Dense output (the accepted steps of the integrator) ───────────────────

  @override
  BcDenseResult integrateDenseShot(
    BcShot shot,
    BcTrajectoryRequest request, {
    double relativeTolerance = 1e-6,
    double absoluteTolerance = 1e-6,
  }) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final req = arena<BCLIBCFFI_TrajectoryRequest>();
    final pRecs = arena<ffi.Pointer<BCLIBCFFI_TrajectoryData>>();
    final pCount = arena<ffi.Int32>();
    final pDense = arena<ffi.Pointer<BCLIBCFFI_BaseTrajData>>();
    final pDenseCount = arena<ffi.Int32>();
    final pReason = arena<ffi.Int32>();
    final stats = arena<BCLIBCFFI_StepStats>();
    final err = arena<BCLIBCFFI_Error>();

    shot._fill(p.ref, arena);
    _fillRequest(req.ref, request);

    final adaptive = shot.method.isAdaptive;
    final st = adaptive
        ? BCLIBCFFI_integrate_adaptive_shot(
            p,
            shot.method.value,
            relativeTolerance,
            absoluteTolerance,
            req,
            1,
            pRecs,
            pCount,
            pDense,
            pDenseCount,
            pReason,
            stats,
            err,
          )
        : BCLIBCFFI_integrate_dense_shot(
            p,
            req,
            1,
            pRecs,
            pCount,
            pDense,
            pDenseCount,
            pReason,
            err,
          );
    if (st != 0) _throwFromError(err.ref);

    final count = pCount.value;
    final denseCount = pDenseCount.value;
    final recs = pRecs.value;
    final dense = pDense.value;
    try {
      return BcDenseResult(
        List<BcTrajectoryData>.generate(
          count,
          (i) => _trajDataFromNative(recs[i]),
        ),
        BcTerminationReason.fromValue(pReason.value),
        List<BcBaseTrajData>.generate(
          denseCount,
          (i) => _baseTrajFromNative(dense[i]),
        ),
        adaptive ? BcStepStats(stats.ref.accepted, stats.ref.rejected) : null,
      );
    } finally {
      if (count > 0) BCLIBCFFI_free_trajectory(recs);
      if (denseCount > 0) BCLIBCFFI_free_base_trajectory(dense);
    }
  });

  @override
  BcBaseTrajData denseGetAt(
    List<BcBaseTrajData> steps,
    BcBaseTrajInterpKey key,
    double value, {
    double startFromTime = 0.0,
  }) => using((arena) {
    final out = arena<BCLIBCFFI_BaseTrajData>();
    final err = arena<BCLIBCFFI_Error>();
    final st = BCLIBCFFI_dense_get_at(
      _stepsToNative(steps, arena),
      steps.length,
      key.value,
      value,
      startFromTime,
      out,
      err,
    );
    if (st != 0) _throwFromError(err.ref);
    return _baseTrajFromNative(out.ref);
  });

  @override
  BcBaseTrajData denseGetAtSlantHeight(
    List<BcBaseTrajData> steps,
    double lookAngleRad,
    double value,
  ) => using((arena) {
    final out = arena<BCLIBCFFI_BaseTrajData>();
    final err = arena<BCLIBCFFI_Error>();
    final st = BCLIBCFFI_dense_get_at_slant_height(
      _stepsToNative(steps, arena),
      steps.length,
      lookAngleRad,
      value,
      out,
      err,
    );
    if (st != 0) _throwFromError(err.ref);
    return _baseTrajFromNative(out.ref);
  });

  @override
  BcTrajectoryData trajectoryDataFromStep(
    BcShot shot,
    BcBaseTrajData step, {
    int flag = 0,
  }) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final stepPtr = arena<BCLIBCFFI_BaseTrajData>();
    final out = arena<BCLIBCFFI_TrajectoryData>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    _fillBaseTraj(stepPtr.ref, step);
    final st = BCLIBCFFI_trajectory_data_from_step_shot(
      p,
      stepPtr,
      flag,
      out,
      err,
    );
    if (st != 0) _throwFromError(err.ref);
    return _trajDataFromNative(out.ref);
  });
}
