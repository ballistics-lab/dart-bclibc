// Async counterpart to [Calculator].
//
// Mirrors the same three public methods (barrelElevationForTarget,
// setWeaponZero, fire) but returns Futures.
//
// Backed by a platform-conditional engine (see async_engine_io.dart /
// async_engine_web.dart): on native, each call runs on a fresh isolate so it
// doesn't block the caller's isolate; on web, the wasm module is loaded once
// (the only inherently async part — dart:js_interop module instantiation)
// and every call after that runs synchronously through it, since Isolate.run
// isn't available on web.

import 'package:dart_bclibc/ffi/bclibc_types.dart';
import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';

import 'async_engine_io.dart'
    if (dart.library.js_interop) 'async_engine_web.dart'
    as engine;
import 'calculator_defaults.dart' show defaultConfig;

class AsyncCalculator {
  final BcIntegrationMethod method;
  final BcConfig config;

  AsyncCalculator({this.method = BcIntegrationMethod.rk4, BcConfig? config})
    : config = config ?? defaultConfig;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Async counterpart to [Calculator.barrelElevationForTarget].
  Future<Angular> barrelElevationForTarget(
    Shot shot,
    Distance targetDistance,
  ) => engine.asyncBarrelElevationForTarget(
    shot,
    targetDistance,
    method,
    config,
  );

  /// Async counterpart to [Calculator.setWeaponZero].
  ///
  /// The zero-finding itself runs off-isolate (native) or through the
  /// loaded wasm engine (web); the resulting elevation is then applied to
  /// [shot] on the caller's isolate, since [shot] is mutated in place and
  /// mutations made inside a spawned isolate would not be visible here.
  Future<Angular> setWeaponZero(Shot shot, Distance zeroDistance) async {
    final elev = await barrelElevationForTarget(shot, zeroDistance);
    shot.weapon.zeroElevation = elev;
    shot.relativeAngle = Angular.radian(0);
    return elev;
  }

  /// Async counterpart to [Calculator.fire].
  Future<HitResult> fire({
    required Shot shot,
    required Distance trajectoryRange,
    Distance? trajectoryStep,
    double timeStep = 0.0,
    int filterFlags = 8, // BCLIBCFFI_TrajFlag.BCLIBCFFI_TRAJ_FLAG_RANGE
    bool raiseRangeError = true,
  }) => engine.asyncFire(
    shot: shot,
    trajectoryRange: trajectoryRange,
    trajectoryStep: trajectoryStep,
    timeStep: timeStep,
    filterFlags: filterFlags,
    raiseRangeError: raiseRangeError,
    method: method,
    config: config,
  );
}
