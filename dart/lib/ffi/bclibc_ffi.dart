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
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'bclibc_bindings.g.dart';
import 'bclibc_types.dart';

export 'bclibc_types.dart';

// ============================================================================
// Library loader
// ============================================================================

/// The name CocoaPods gives the compiled framework on iOS/macOS is the
/// *podspec's* name — `dart_bclibc_flutter`, the Flutter wrapper package's
/// own name, not this package's (`dart_bclibc`) or the CMake target's
/// (`bclibc_ffi`) — every source file the podspec declares compiles into one
/// framework binary named after the pod itself.
const String _iosMacosFrameworkName = 'dart_bclibc_flutter';

String _libName() {
  if (Platform.isWindows) return 'bclibc_ffi.dll';
  if (Platform.isMacOS) return 'libbclibc_ffi.dylib';
  return 'libbclibc_ffi.so';
}

ffi.DynamicLibrary _openLibrary() {
  final env = Platform.environment['BCLIBC_FFI_PATH'];
  if (env != null && env.isNotEmpty) return ffi.DynamicLibrary.open(env);

  final libName = _libName();
  final platform = Platform.operatingSystem; // 'linux', 'macos', 'windows', 'android', 'ios'

  // 1. `package:` URI resolution — works in JIT mode (`dart run`/`flutter
  //    run`), backed by .dart_tool/package_config.json and the location
  //    `dart run dart_bclibc:build_native` copies the built library to. Not
  //    applicable to iOS at all (no JIT there, ever), skipped for that
  //    platform.
  if (!Platform.isIOS) {
    try {
      final uri = Isolate.resolvePackageUriSync(
        Uri.parse('package:dart_bclibc/native/$platform/$libName'),
      );
      if (uri != null) {
        final path = uri.toFilePath();
        if (File(path).existsSync()) return ffi.DynamicLibrary.open(path);
      }
    } on UnsupportedError {
      // AOT/release build — expected, fall through to the next strategy.
    }
  }

  // 2. iOS/macOS via the `dart_bclibc_flutter` CocoaPods framework: a bare
  // `<Framework>.framework/<Framework>` reference, resolved by dyld through
  // the app bundle's own embedded search paths (Xcode wires this up
  // automatically when the framework is linked in).
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return ffi.DynamicLibrary.open(
        '$_iosMacosFrameworkName.framework/$_iosMacosFrameworkName',
      );
    } catch (_) {
      // Not running inside the Flutter plugin's framework bundle — for iOS
      // there's no other option (see the throw below); macOS falls through
      // to the executable-relative strategy, for the plain-Dart-via-
      // `build_native` desktop case.
      if (Platform.isIOS) rethrow;
    }
  }

  // 3. Android: bundled via jniLibs, loadable by bare name through the
  //    system's standard shared-library search path.
  if (Platform.isAndroid) return ffi.DynamicLibrary.open(libName);

  // 4. Executable-relative — where Flutter's own native-library bundling
  //    places plugin libraries on Linux/Windows in a compiled release build
  //    (build/linux/x64/release/bundle/lib/*.so and equivalents), or where a
  //    plain `dart run dart_bclibc:build_native` + `dart compile exe` desktop
  //    workflow would place a manually-copied library next to the binary.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    p.join(exeDir, 'lib', libName),
    p.join(exeDir, libName),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return ffi.DynamicLibrary.open(candidate);
    }
  }

  throw FileSystemException(
    'Could not locate $libName (tried package: URI and ${candidates.join(", ")}). '
    'Run `dart run dart_bclibc:build_native` for a plain Dart project, or add '
    'dart_bclibc_flutter as a dependency for a Flutter app.',
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
