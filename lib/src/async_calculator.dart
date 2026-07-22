// Async counterpart to [Calculator].
//
// Mirrors the same three public methods (barrelElevationForTarget,
// setWeaponZero, fire) but returns Futures. Each call runs the native FFI
// work on a fresh isolate via Isolate.run, so it neither blocks the caller
// nor depends on any state held by the calling isolate.
//
// This keeps the public surface forward-compatible with the planned WASM
// binding for web, whose JS interop can only ever be async.

import 'dart:isolate';

import 'package:dart_bclibc/ffi/bclibc_bindings.g.dart';
import 'package:dart_bclibc/src/calculator.dart';
import 'package:dart_bclibc/ffi/bclibc_ffi.dart';
import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';

class AsyncCalculator {
  final BCLIBCFFI_IntegrationMethod method;
  final BcConfig config;

  AsyncCalculator({
    this.method = BCLIBCFFI_IntegrationMethod.BCLIBCFFI_INTEGRATION_RK4,
    BcConfig? config,
  }) : config = config ?? defaultConfig;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Async counterpart to [Calculator.barrelElevationForTarget].
  Future<Angular> barrelElevationForTarget(
    Shot shot,
    Distance targetDistance,
  ) {
    final method = this.method;
    final config = this.config;
    return Isolate.run(
      () => Calculator(
        method: method,
        config: config,
      ).barrelElevationForTarget(shot, targetDistance),
    );
  }

  /// Async counterpart to [Calculator.setWeaponZero].
  ///
  /// The zero-finding itself runs off-isolate; the resulting elevation is
  /// then applied to [shot] on the caller's isolate, since [shot] is mutated
  /// in place and mutations made inside the spawned isolate would not be
  /// visible here.
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
  }) {
    final method = this.method;
    final config = this.config;
    return Isolate.run(
      () => Calculator(method: method, config: config).fire(
        shot: shot,
        trajectoryRange: trajectoryRange,
        trajectoryStep: trajectoryStep,
        timeStep: timeStep,
        filterFlags: filterFlags,
        raiseRangeError: raiseRangeError,
      ),
    );
  }
}
