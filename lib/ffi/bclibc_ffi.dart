// ignore_for_file: dangling_library_doc_comments
/// Thin Dart wrapper over the bclibc C FFI layer.
///
/// API:
///   findApexShot, findMaxRangeShot, findZeroAngleShot, integrateShot, integrateAtShot
///
/// Usage:
///   final bc = BcLibC.open();
///   final hit = bc.integrateShot(shot, request);

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'bclibc_bindings.g.dart';
import 'bclibc_types.dart';

export 'bclibc_types.dart';

// ============================================================================
// Library loader
// ============================================================================

ffi.DynamicLibrary _openLibrary() {
  String lib(String name) {
    final env = Platform.environment['BCLIBC_FFI_PATH'];
    if (env != null && env.isNotEmpty) return env;
    // Prefer the Flutter-built bundle so tests use the same binary as the app.
    // Falls back to the standalone cmake build (make build-bclibc) for CI /
    // fresh checkouts where flutter build hasn't run yet.
    for (final mode in const ['debug', 'profile', 'release']) {
      final p = 'build/linux/x64/$mode/bundle/lib/$name';
      if (File(p).existsSync()) return p;
    }
    final devPath = 'build/bclibc/$name';
    if (File(devPath).existsSync()) return devPath;
    return name; // bundled app (RPATH / system lookup)
  }

  if (Platform.isLinux) return ffi.DynamicLibrary.open(lib('libbclibc_ffi.so'));
  if (Platform.isAndroid) return ffi.DynamicLibrary.open('libbclibc_ffi.so');
  if (Platform.isWindows) return ffi.DynamicLibrary.open(lib('bclibc_ffi.dll'));
  if (Platform.isMacOS) {
    return ffi.DynamicLibrary.open(lib('libbclibc_ffi.dylib'));
  }
  throw UnsupportedError(
    'bclibc_ffi: unsupported platform ${Platform.operatingSystem}',
  );
}

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

Never _throwFromError(BCLIBCFFI_Error err) {
  final msg = _charArrayToString(err.message, 512);
  if (err.code == BCLIBCFFI_Status.BCLIBCFFI_ERR_OUT_OF_RANGE.value) {
    throw BcException(
      code: err.code,
      message: msg,
      requestedDistanceFt: err.f64_0,
      maxRangeFt: err.f64_1,
      lookAngleRad: err.f64_2,
    );
  }
  if (err.code == BCLIBCFFI_Status.BCLIBCFFI_ERR_ZERO_FINDING.value) {
    throw BcException(
      code: err.code,
      message: msg,
      zeroFindingError: err.f64_0,
      lastBarrelElevationRad: err.f64_1,
      iterationsCount: err.i32_0,
    );
  }
  throw BcException(code: err.code, message: msg);
}

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

// ============================================================================
// Main API class
// ============================================================================

class BcLibC implements BcEngine {
  final BcLibCFFIBindings _b;

  BcLibC._(this._b);

  /// Open the native library. Call once per isolate.
  factory BcLibC.open() => BcLibC._(BcLibCFFIBindings(_openLibrary()));

  // ── Utility functions ──────────────────────────────────────────────────────

  @override
  double getCorrection(double distanceFt, double offsetFt) =>
      _b.BCLIBCFFI_get_correction(distanceFt, offsetFt);

  @override
  double calculateEnergy(double bulletWeightGrain, double velocityFps) =>
      _b.BCLIBCFFI_calculate_energy(bulletWeightGrain, velocityFps);

  @override
  double calculateOgw(double bulletWeightGrain, double velocityFps) =>
      _b.BCLIBCFFI_calculate_ogw(bulletWeightGrain, velocityFps);

  // ── BcShot-based API (all physics conversion in C++) ──────────────────────

  @override
  BcTrajectoryData findApexShot(BcShot shot) => using((arena) {
    final p = arena<BCLIBCFFI_Shot>();
    final out = arena<BCLIBCFFI_TrajectoryData>();
    final err = arena<BCLIBCFFI_Error>();
    shot._fill(p.ref, arena);
    final st = _b.BCLIBCFFI_find_apex_shot(p, out, err);
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
    final st = _b.BCLIBCFFI_find_max_range_shot(
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
    final st = _b.BCLIBCFFI_find_zero_angle_shot(p, distanceFt, outAngle, err);
    if (st != 0) _throwFromError(err.ref);
    return outAngle.value;
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
    req.ref.range_limit_ft = request.rangeLimitFt;
    req.ref.range_step_ft = request.rangeStepFt;
    req.ref.time_step = request.timeStep;
    req.ref.filter_flags = request.filterFlags;

    final st = _b.BCLIBCFFI_integrate_shot(p, req, pPtr, pCount, pReason, err);
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
      if (count > 0) _b.BCLIBCFFI_free_trajectory(rawPtr);
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
    final st = _b.BCLIBCFFI_integrate_at_shot(
      p,
      key.value,
      targetValue,
      out,
      err,
    );
    if (st != 0) _throwFromError(err.ref);
    return BcInterception(
      _baseTrajFromNative(out.ref.raw_data),
      _trajDataFromNative(out.ref.full_data),
    );
  });
}
