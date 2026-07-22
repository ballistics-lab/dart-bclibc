// Web binding for the bclibc C ABI (bclibc_ffi.h / BCLIBCFFI_*), compiled to
// wasm via bclibc/build_wasm.sh and loaded through dart:js_interop.
//
// Talks directly to the same flat BCLIBCFFI_* exports the native dart:ffi
// binding (bclibc_ffi.dart) uses — no Embind, no wasm_ffi (which doesn't
// support ffi.Struct as of writing: github.com/vm75/wasm_ffi#10). Struct
// field byte offsets aren't hardcoded here: they're read once at module-load
// time from BCLIBCFFI_get_layout(), which computes them via offsetof()/
// sizeof() in whichever compiler built the wasm module, so this file can
// never silently drift from the C struct layout.
//
// Loading the module is the only async part; once loaded, every call below
// is a plain synchronous JS call into already-instantiated wasm.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'bclibc_types.dart';

export 'bclibc_types.dart';

// ============================================================================
// Module loading
// ============================================================================

Future<JSObject> _loadModule(String scriptUrl, String globalName) async {
  if (!globalContext.has(globalName)) {
    final completer = Completer<void>();
    void onLoad(web.Event _) => completer.complete();
    void onError(web.Event _) =>
        completer.completeError('Failed to load script: $scriptUrl');

    final script = web.HTMLScriptElement()..src = scriptUrl;
    script.addEventListener('load', onLoad.toJS);
    script.addEventListener('error', onError.toJS);
    web.document.head!.appendChild(script);
    await completer.future;
  }

  final factory = globalContext.getProperty<JSFunction>(globalName.toJS);
  final result = factory.callAsFunction();
  final promise = result! as JSPromise<JSObject>;
  return await promise.toDart;
}

// ============================================================================
// ABI layout (discovered at runtime via BCLIBCFFI_get_layout — see
// bclibc/src/ffi/bclibc_ffi.cpp for the fixed field order this reads)
// ============================================================================

class _Layout {
  final List<int> v;
  _Layout(this.v);

  int get configSize => v[0];
  int get configStepMultiplier => v[1];
  int get configZeroFindingAccuracy => v[2];
  int get configMinimumVelocity => v[3];
  int get configMaximumDrop => v[4];
  int get configMaxIterations => v[5];
  int get configGravityConstant => v[6];
  int get configMinimumAltitude => v[7];

  int get windSize => v[8];
  int get windVelocityFps => v[9];
  int get windDirectionFromRad => v[10];
  int get windUntilDistanceFt => v[11];
  int get windMaxDistanceFt => v[12];

  int get shotSize => v[13];
  int get shotBc => v[14];
  int get shotWeightGrain => v[15];
  int get shotDiameterInch => v[16];
  int get shotLengthInch => v[17];
  int get shotMuzzleVelocityFps => v[18];
  int get shotSightHeightFt => v[19];
  int get shotTwistInch => v[20];
  int get shotTempC => v[21];
  int get shotPressureHpa => v[22];
  int get shotAltitudeFt => v[23];
  int get shotHumidity => v[24];
  int get shotMachData => v[25];
  int get shotCdData => v[26];
  int get shotDragTableSize => v[27];
  int get shotWinds => v[28];
  int get shotWindCount => v[29];
  int get shotLookAngleRad => v[30];
  int get shotBarrelElevationRad => v[31];
  int get shotBarrelAzimuthRad => v[32];
  int get shotCantAngleRad => v[33];
  int get shotLatitudeDeg => v[34];
  int get shotAzimuthDeg => v[35];
  int get shotConfig => v[36];
  int get shotMethod => v[37];

  int get reqSize => v[38];
  int get reqRangeLimitFt => v[39];
  int get reqRangeStepFt => v[40];
  int get reqTimeStep => v[41];
  int get reqFilterFlags => v[42];

  int get trajSize => v[43];
  int get trajTime => v[44];
  int get trajDistanceFt => v[45];
  int get trajVelocityFps => v[46];
  int get trajMach => v[47];
  int get trajHeightFt => v[48];
  int get trajSlantHeightFt => v[49];
  int get trajDropAngleRad => v[50];
  int get trajWindageFt => v[51];
  int get trajWindageAngleRad => v[52];
  int get trajSlantDistanceFt => v[53];
  int get trajAngleRad => v[54];
  int get trajDensityRatio => v[55];
  int get trajDrag => v[56];
  int get trajEnergyFtLb => v[57];
  int get trajOgwLb => v[58];
  int get trajFlag => v[59];

  int get maxRangeSize => v[60];
  int get maxRangeMaxRangeFt => v[61];
  int get maxRangeAngleAtMaxRad => v[62];

  int get baseTrajSize => v[63];
  int get baseTrajTime => v[64];
  int get baseTrajPx => v[65];
  int get baseTrajPy => v[66];
  int get baseTrajPz => v[67];
  int get baseTrajVx => v[68];
  int get baseTrajVy => v[69];
  int get baseTrajVz => v[70];
  int get baseTrajMach => v[71];

  int get interceptionSize => v[72];
  int get interceptionRawData => v[73];
  int get interceptionFullData => v[74];

  int get errorSize => v[75];
  int get errorCode => v[76];
  int get errorMessage => v[77];
  int get errorF64_0 => v[78];
  int get errorF64_1 => v[79];
  int get errorF64_2 => v[80];
  int get errorI32_0 => v[81];

  static const int fieldCount = 82;
}

// ============================================================================
// Wasm memory access
// ============================================================================

/// Re-fetched on every access rather than cached: with ALLOW_MEMORY_GROWTH=1
/// Emscripten may replace the underlying ArrayBuffer (grow), which would
/// silently detach any previously-fetched view.
ByteData _heap(JSObject module) {
  final u8 = module.getProperty<JSUint8Array>('HEAPU8'.toJS).toDart;
  return u8.buffer.asByteData(u8.offsetInBytes, u8.lengthInBytes);
}

class _WasmArena {
  final JSObject module;
  final List<int> _ptrs = [];
  _WasmArena(this.module);

  int malloc(int bytes) {
    final ptr = module.callMethodVarArgs<JSNumber>('_malloc'.toJS, [
      bytes.toJS,
    ]).toDartInt;
    _ptrs.add(ptr);
    return ptr;
  }

  void freeAll() {
    for (final p in _ptrs) {
      module.callMethodVarArgs<JSAny?>('_free'.toJS, [p.toJS]);
    }
    _ptrs.clear();
  }
}

T _using<T>(JSObject module, T Function(_WasmArena arena) fn) {
  final arena = _WasmArena(module);
  try {
    return fn(arena);
  } finally {
    arena.freeAll();
  }
}

int _call(JSObject module, String name, List<int> ptrArgs) => module
    .callMethodVarArgs<JSNumber>(name.toJS, [for (final a in ptrArgs) a.toJS])
    .toDartInt;

// ============================================================================
// Struct marshalling
// ============================================================================

void _writeShot(
  ByteData bd,
  int ptr,
  _Layout l,
  BcShot shot,
  int machPtr,
  int cdPtr,
  int windsPtr,
) {
  bd.setFloat64(ptr + l.shotBc, shot.bc, Endian.little);
  bd.setFloat64(ptr + l.shotWeightGrain, shot.weightGrain, Endian.little);
  bd.setFloat64(ptr + l.shotDiameterInch, shot.diameterInch, Endian.little);
  bd.setFloat64(ptr + l.shotLengthInch, shot.lengthInch, Endian.little);
  bd.setFloat64(
    ptr + l.shotMuzzleVelocityFps,
    shot.muzzleVelocityFps,
    Endian.little,
  );
  bd.setFloat64(ptr + l.shotSightHeightFt, shot.sightHeightFt, Endian.little);
  bd.setFloat64(ptr + l.shotTwistInch, shot.twistInch, Endian.little);
  bd.setFloat64(ptr + l.shotTempC, shot.tempC, Endian.little);
  bd.setFloat64(ptr + l.shotPressureHpa, shot.pressureHpa, Endian.little);
  bd.setFloat64(ptr + l.shotAltitudeFt, shot.altitudeFt, Endian.little);
  bd.setFloat64(ptr + l.shotHumidity, shot.humidity, Endian.little);

  bd.setInt32(ptr + l.shotMachData, machPtr, Endian.little);
  bd.setInt32(ptr + l.shotCdData, cdPtr, Endian.little);
  bd.setInt32(ptr + l.shotDragTableSize, shot.dragTable.length, Endian.little);
  bd.setInt32(ptr + l.shotWinds, windsPtr, Endian.little);
  bd.setInt32(ptr + l.shotWindCount, shot.winds.length, Endian.little);

  bd.setFloat64(ptr + l.shotLookAngleRad, shot.lookAngleRad, Endian.little);
  bd.setFloat64(
    ptr + l.shotBarrelElevationRad,
    shot.barrelElevationRad,
    Endian.little,
  );
  bd.setFloat64(
    ptr + l.shotBarrelAzimuthRad,
    shot.barrelAzimuthRad,
    Endian.little,
  );
  bd.setFloat64(ptr + l.shotCantAngleRad, shot.cantAngleRad, Endian.little);
  bd.setFloat64(ptr + l.shotLatitudeDeg, shot.latitudeDeg, Endian.little);
  bd.setFloat64(ptr + l.shotAzimuthDeg, shot.azimuthDeg, Endian.little);

  final cfg = ptr + l.shotConfig;
  bd.setFloat64(
    cfg + l.configStepMultiplier,
    shot.config.stepMultiplier,
    Endian.little,
  );
  bd.setFloat64(
    cfg + l.configZeroFindingAccuracy,
    shot.config.zeroFindingAccuracy,
    Endian.little,
  );
  bd.setFloat64(
    cfg + l.configMinimumVelocity,
    shot.config.minimumVelocity,
    Endian.little,
  );
  bd.setFloat64(
    cfg + l.configMaximumDrop,
    shot.config.maximumDrop,
    Endian.little,
  );
  bd.setInt32(
    cfg + l.configMaxIterations,
    shot.config.maxIterations,
    Endian.little,
  );
  bd.setFloat64(
    cfg + l.configGravityConstant,
    shot.config.gravityConstant,
    Endian.little,
  );
  bd.setFloat64(
    cfg + l.configMinimumAltitude,
    shot.config.minimumAltitude,
    Endian.little,
  );

  bd.setInt32(ptr + l.shotMethod, shot.method.value, Endian.little);
}

int _fillShot(_WasmArena arena, ByteData bd, _Layout l, BcShot shot) {
  final shotPtr = arena.malloc(l.shotSize);

  int machPtr = 0, cdPtr = 0;
  if (shot.dragTable.isNotEmpty) {
    machPtr = arena.malloc(shot.dragTable.length * 8);
    cdPtr = arena.malloc(shot.dragTable.length * 8);
    for (var i = 0; i < shot.dragTable.length; i++) {
      bd.setFloat64(machPtr + i * 8, shot.dragTable[i].mach, Endian.little);
      bd.setFloat64(cdPtr + i * 8, shot.dragTable[i].cd, Endian.little);
    }
  }

  int windsPtr = 0;
  if (shot.winds.isNotEmpty) {
    windsPtr = arena.malloc(shot.winds.length * l.windSize);
    for (var i = 0; i < shot.winds.length; i++) {
      final w = windsPtr + i * l.windSize;
      bd.setFloat64(
        w + l.windVelocityFps,
        shot.winds[i].velocityFps,
        Endian.little,
      );
      bd.setFloat64(
        w + l.windDirectionFromRad,
        shot.winds[i].directionFromRad,
        Endian.little,
      );
      bd.setFloat64(
        w + l.windUntilDistanceFt,
        shot.winds[i].untilDistanceFt,
        Endian.little,
      );
      bd.setFloat64(
        w + l.windMaxDistanceFt,
        shot.winds[i].maxDistanceFt,
        Endian.little,
      );
    }
  }

  _writeShot(bd, shotPtr, l, shot, machPtr, cdPtr, windsPtr);
  return shotPtr;
}

BcTrajectoryData _readTrajData(
  ByteData bd,
  int base,
  _Layout l,
) => BcTrajectoryData(
  time: bd.getFloat64(base + l.trajTime, Endian.little),
  distanceFt: bd.getFloat64(base + l.trajDistanceFt, Endian.little),
  velocityFps: bd.getFloat64(base + l.trajVelocityFps, Endian.little),
  mach: bd.getFloat64(base + l.trajMach, Endian.little),
  heightFt: bd.getFloat64(base + l.trajHeightFt, Endian.little),
  slantHeightFt: bd.getFloat64(base + l.trajSlantHeightFt, Endian.little),
  dropAngleRad: bd.getFloat64(base + l.trajDropAngleRad, Endian.little),
  windageFt: bd.getFloat64(base + l.trajWindageFt, Endian.little),
  windageAngleRad: bd.getFloat64(base + l.trajWindageAngleRad, Endian.little),
  slantDistanceFt: bd.getFloat64(base + l.trajSlantDistanceFt, Endian.little),
  angleRad: bd.getFloat64(base + l.trajAngleRad, Endian.little),
  densityRatio: bd.getFloat64(base + l.trajDensityRatio, Endian.little),
  drag: bd.getFloat64(base + l.trajDrag, Endian.little),
  energyFtLb: bd.getFloat64(base + l.trajEnergyFtLb, Endian.little),
  ogwLb: bd.getFloat64(base + l.trajOgwLb, Endian.little),
  flag: bd.getInt32(base + l.trajFlag, Endian.little),
);

BcBaseTrajData _readBaseTraj(ByteData bd, int base, _Layout l) =>
    BcBaseTrajData(
      time: bd.getFloat64(base + l.baseTrajTime, Endian.little),
      px: bd.getFloat64(base + l.baseTrajPx, Endian.little),
      py: bd.getFloat64(base + l.baseTrajPy, Endian.little),
      pz: bd.getFloat64(base + l.baseTrajPz, Endian.little),
      vx: bd.getFloat64(base + l.baseTrajVx, Endian.little),
      vy: bd.getFloat64(base + l.baseTrajVy, Endian.little),
      vz: bd.getFloat64(base + l.baseTrajVz, Endian.little),
      mach: bd.getFloat64(base + l.baseTrajMach, Endian.little),
    );

Never _throwFromError(ByteData bd, int errPtr, _Layout l) {
  final code = bd.getInt32(errPtr + l.errorCode, Endian.little);
  final msgStart = errPtr + l.errorMessage;
  final bytes = <int>[];
  for (var i = 0; i < 512; i++) {
    final b = bd.getUint8(msgStart + i);
    if (b == 0) break;
    bytes.add(b);
  }
  final message = utf8.decode(bytes);

  const errOutOfRange = 2; // BCLIBCFFI_ERR_OUT_OF_RANGE
  const errZeroFinding = 3; // BCLIBCFFI_ERR_ZERO_FINDING
  if (code == errOutOfRange) {
    throw BcException(
      code: code,
      message: message,
      requestedDistanceFt: bd.getFloat64(errPtr + l.errorF64_0, Endian.little),
      maxRangeFt: bd.getFloat64(errPtr + l.errorF64_1, Endian.little),
      lookAngleRad: bd.getFloat64(errPtr + l.errorF64_2, Endian.little),
    );
  }
  if (code == errZeroFinding) {
    throw BcException(
      code: code,
      message: message,
      zeroFindingError: bd.getFloat64(errPtr + l.errorF64_0, Endian.little),
      lastBarrelElevationRad: bd.getFloat64(
        errPtr + l.errorF64_1,
        Endian.little,
      ),
      iterationsCount: bd.getInt32(errPtr + l.errorI32_0, Endian.little),
    );
  }
  throw BcException(code: code, message: message);
}

// ============================================================================
// Main API class
// ============================================================================

class BcLibCWeb implements BcEngine {
  final JSObject _module;
  final _Layout _layout;

  BcLibCWeb._(this._module, this._layout);

  /// Loads and instantiates the wasm module. Call once per app; the result
  /// can be reused for any number of shots/calls.
  ///
  /// [scriptUrl] defaults to where Flutter web serves this package's own
  /// bundled asset (declared under `flutter.assets` in pubspec.yaml) —
  /// see `assets/wasm/` in the package root. Override it if you're loading
  /// a differently-built or differently-hosted artifact (e.g. in a plain
  /// `dart test -p chrome` run, which doesn't go through Flutter's asset
  /// pipeline).
  static Future<BcLibCWeb> open({
    String scriptUrl = 'assets/packages/dart_bclibc/assets/wasm/bclibc_ffi.js',
    String globalName = 'bclibc_ffi',
  }) async {
    final module = await _loadModule(scriptUrl, globalName);
    final layoutBuf = module.callMethodVarArgs<JSNumber>('_malloc'.toJS, [
      (_Layout.fieldCount * 4).toJS,
    ]).toDartInt;
    final n = module.callMethodVarArgs<JSNumber>('_BCLIBCFFI_get_layout'.toJS, [
      layoutBuf.toJS,
      _Layout.fieldCount.toJS,
    ]).toDartInt;
    if (n != _Layout.fieldCount) {
      module.callMethodVarArgs<JSAny?>('_free'.toJS, [layoutBuf.toJS]);
      throw StateError(
        'BCLIBCFFI_get_layout returned $n fields, expected ${_Layout.fieldCount} '
        '(bclibc_ffi_web.dart is out of sync with bclibc_ffi.cpp)',
      );
    }
    final bd = _heap(module);
    final values = [
      for (var i = 0; i < n; i++) bd.getInt32(layoutBuf + i * 4, Endian.little),
    ];
    module.callMethodVarArgs<JSAny?>('_free'.toJS, [layoutBuf.toJS]);
    return BcLibCWeb._(module, _Layout(values));
  }

  // ── Utility functions ──────────────────────────────────────────────────────

  @override
  double getCorrection(double distanceFt, double offsetFt) => (_callDouble(
    _module,
    '_BCLIBCFFI_get_correction',
    [distanceFt, offsetFt],
  ));

  @override
  double calculateEnergy(double bulletWeightGrain, double velocityFps) =>
      _callDouble(_module, '_BCLIBCFFI_calculate_energy', [
        bulletWeightGrain,
        velocityFps,
      ]);

  @override
  double calculateOgw(double bulletWeightGrain, double velocityFps) =>
      _callDouble(_module, '_BCLIBCFFI_calculate_ogw', [
        bulletWeightGrain,
        velocityFps,
      ]);

  // ── BcShot-based API ────────────────────────────────────────────────────

  @override
  BcTrajectoryData findApexShot(BcShot shot) => _using(_module, (arena) {
    final bd = _heap(_module);
    final shotPtr = _fillShot(arena, bd, _layout, shot);
    final outPtr = arena.malloc(_layout.trajSize);
    final errPtr = arena.malloc(_layout.errorSize);
    final st = _call(_module, '_BCLIBCFFI_find_apex_shot', [
      shotPtr,
      outPtr,
      errPtr,
    ]);
    if (st != 0) _throwFromError(_heap(_module), errPtr, _layout);
    return _readTrajData(_heap(_module), outPtr, _layout);
  });

  @override
  BcMaxRangeResult findMaxRangeShot(
    BcShot shot, {
    double lowAngleDeg = 0.0,
    double highAngleDeg = 45.0,
  }) => _using(_module, (arena) {
    final bd = _heap(_module);
    final shotPtr = _fillShot(arena, bd, _layout, shot);
    final outPtr = arena.malloc(_layout.maxRangeSize);
    final errPtr = arena.malloc(_layout.errorSize);

    // BCLIBCFFI_find_max_range_shot takes two doubles inline; pass them via
    // dedicated scratch doubles is unnecessary — the JS call takes plain
    // numbers directly.
    final st = _module.callMethodVarArgs<JSNumber>(
      '_BCLIBCFFI_find_max_range_shot'.toJS,
      [
        shotPtr.toJS,
        lowAngleDeg.toJS,
        highAngleDeg.toJS,
        outPtr.toJS,
        errPtr.toJS,
      ],
    ).toDartInt;
    if (st != 0) _throwFromError(_heap(_module), errPtr, _layout);
    final bd2 = _heap(_module);
    return BcMaxRangeResult(
      bd2.getFloat64(outPtr + _layout.maxRangeMaxRangeFt, Endian.little),
      bd2.getFloat64(outPtr + _layout.maxRangeAngleAtMaxRad, Endian.little),
    );
  });

  @override
  double findZeroAngleShot(BcShot shot, double distanceFt) =>
      _using(_module, (arena) {
        final bd = _heap(_module);
        final shotPtr = _fillShot(arena, bd, _layout, shot);
        final outAnglePtr = arena.malloc(8);
        final errPtr = arena.malloc(_layout.errorSize);
        final st = _module.callMethodVarArgs<JSNumber>(
          '_BCLIBCFFI_find_zero_angle_shot'.toJS,
          [shotPtr.toJS, distanceFt.toJS, outAnglePtr.toJS, errPtr.toJS],
        ).toDartInt;
        if (st != 0) _throwFromError(_heap(_module), errPtr, _layout);
        return _heap(_module).getFloat64(outAnglePtr, Endian.little);
      });

  @override
  BcHitResult integrateShot(BcShot shot, BcTrajectoryRequest request) =>
      _using(_module, (arena) {
        final bd = _heap(_module);
        final shotPtr = _fillShot(arena, bd, _layout, shot);

        final reqPtr = arena.malloc(_layout.reqSize);
        bd.setFloat64(
          reqPtr + _layout.reqRangeLimitFt,
          request.rangeLimitFt,
          Endian.little,
        );
        bd.setFloat64(
          reqPtr + _layout.reqRangeStepFt,
          request.rangeStepFt,
          Endian.little,
        );
        bd.setFloat64(
          reqPtr + _layout.reqTimeStep,
          request.timeStep,
          Endian.little,
        );
        bd.setInt32(
          reqPtr + _layout.reqFilterFlags,
          request.filterFlags,
          Endian.little,
        );

        final outRecordsPtrPtr = arena.malloc(4);
        final outCountPtr = arena.malloc(4);
        final outReasonPtr = arena.malloc(4);
        final errPtr = arena.malloc(_layout.errorSize);

        final st = _call(_module, '_BCLIBCFFI_integrate_shot', [
          shotPtr,
          reqPtr,
          outRecordsPtrPtr,
          outCountPtr,
          outReasonPtr,
          errPtr,
        ]);
        if (st != 0) _throwFromError(_heap(_module), errPtr, _layout);

        final bd2 = _heap(_module);
        final recordsPtr = bd2.getInt32(outRecordsPtrPtr, Endian.little);
        final count = bd2.getInt32(outCountPtr, Endian.little);
        final reason = bd2.getInt32(outReasonPtr, Endian.little);

        try {
          final records = <BcTrajectoryData>[
            for (var i = 0; i < count; i++)
              _readTrajData(bd2, recordsPtr + i * _layout.trajSize, _layout),
          ];
          return BcHitResult(records, BcTerminationReason.fromValue(reason));
        } finally {
          if (count > 0) {
            _module.callMethodVarArgs<JSAny?>(
              '_BCLIBCFFI_free_trajectory'.toJS,
              [recordsPtr.toJS],
            );
          }
        }
      });

  @override
  BcInterception integrateAtShot(
    BcShot shot,
    BcBaseTrajInterpKey key,
    double targetValue,
  ) => _using(_module, (arena) {
    final bd = _heap(_module);
    final shotPtr = _fillShot(arena, bd, _layout, shot);
    final outPtr = arena.malloc(_layout.interceptionSize);
    final errPtr = arena.malloc(_layout.errorSize);

    final st = _module.callMethodVarArgs<JSNumber>(
      '_BCLIBCFFI_integrate_at_shot'.toJS,
      [
        shotPtr.toJS,
        key.value.toJS,
        targetValue.toJS,
        outPtr.toJS,
        errPtr.toJS,
      ],
    ).toDartInt;
    if (st != 0) _throwFromError(_heap(_module), errPtr, _layout);

    final bd2 = _heap(_module);
    return BcInterception(
      _readBaseTraj(bd2, outPtr + _layout.interceptionRawData, _layout),
      _readTrajData(bd2, outPtr + _layout.interceptionFullData, _layout),
    );
  });
}

double _callDouble(JSObject module, String name, List<double> args) => module
    .callMethodVarArgs<JSNumber>(name.toJS, [for (final a in args) a.toJS])
    .toDartDouble;
