// Calculator — Dart port of the TypeScript Calculator class.
//
// Wraps BcLibC (FFI layer) with the same API surface as the WASM Calculator:
//   barrelElevationForTarget, setWeaponZero, fire
//
// Native-only (imports bclibc_ffi.dart, i.e. dart:ffi) — the actual
// conversion logic lives in calculator_core.dart so it can also be used by
// AsyncCalculator's web engine, which can't depend on this file.
//
// Usage:
//   final calc = Calculator();
//   final elev = calc.barrelElevationForTarget(shot, Distance.meter(1000));
//   calc.setWeaponZero(shot, Distance.meter(100));
//   final result = calc.fire(shot: shot, trajectoryRange: Distance.meter(1000));

import 'package:dart_bclibc/ffi/bclibc_ffi.dart';
import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';

import 'calculator_core.dart';
import 'calculator_defaults.dart';

export 'calculator_defaults.dart';

// ---------------------------------------------------------------------------
// Calculator
// ---------------------------------------------------------------------------

class Calculator {
  final BcIntegrationMethod method;
  final BcConfig config;

  late final BcEngine _engine;

  Calculator({this.method = BcIntegrationMethod.rk4, BcConfig? config})
    : config = config ?? defaultConfig {
    _engine = BcLibC.open();
  }

  /// Wraps an already-open [BcEngine] instead of opening the native library.
  Calculator.withEngine(
    BcEngine engine, {
    this.method = BcIntegrationMethod.rk4,
    BcConfig? config,
  }) : config = config ?? defaultConfig,
       _engine = engine;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the barrel elevation (relative to look-angle) needed to hit
  /// a target at [targetDistance].
  Angular barrelElevationForTarget(Shot shot, Distance targetDistance) =>
      calcBarrelElevationForTarget(
        _engine,
        method,
        config,
        shot,
        targetDistance,
      );

  /// Zeros the weapon by storing the required barrel elevation in
  /// [Weapon.zeroElevation] and resetting [shot.relativeAngle] to zero.
  ///
  /// Any subsequent [Shot] that uses the same [Weapon] instance will
  /// automatically inherit the zero elevation, matching the JS-library
  /// behaviour where `weapon.zeroElevation` is mutable.
  Angular setWeaponZero(Shot shot, Distance zeroDistance) {
    final elev = barrelElevationForTarget(shot, zeroDistance);
    shot.weapon.zeroElevation = elev;
    shot.relativeAngle = Angular.radian(0);
    return elev;
  }

  /// Fires a shot and returns the full trajectory as a [HitResult].
  ///
  /// [trajectoryRange] and [trajectoryStep] accept a [Distance] object or
  /// a raw number in the preferred distance unit.
  HitResult fire({
    required Shot shot,
    required Distance trajectoryRange,
    Distance? trajectoryStep,
    double timeStep = 0.0,
    int filterFlags = 8, // BCLIBCFFI_TrajFlag.BCLIBCFFI_TRAJ_FLAG_RANGE
    bool raiseRangeError = true,
  }) => calcFire(
    _engine,
    method,
    config,
    shot: shot,
    trajectoryRange: trajectoryRange,
    trajectoryStep: trajectoryStep,
    timeStep: timeStep,
    filterFlags: filterFlags,
    raiseRangeError: raiseRangeError,
  );
}
