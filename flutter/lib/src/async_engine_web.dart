// Web (dart:js_interop against a wasm-compiled bclibc_ffi) backend for
// AsyncCalculator.
//
// Loading the wasm module is the only inherently async part (fetch +
// instantiate); once loaded, calls are plain synchronous JS calls, so this
// just awaits a cached engine and then calls the shared conversion logic
// from calculator_core.dart directly — no isolate involved (Isolate.run
// isn't available on web), and no dependency on calculator.dart (which
// imports dart:ffi and so can't be compiled for web).
//
// ignore_for_file: implementation_imports
// Deliberately reaches into dart_bclibc's lib/src — this package and
// dart_bclibc are versioned and published together from the same monorepo.

import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';
import 'package:dart_bclibc/src/calculator_core.dart';

import '../ffi/bclibc_ffi_web.dart';

Future<BcEngine>? _webEngineFuture;

/// The wasm module is stateless/reentrant once loaded, so it's fetched and
/// instantiated once per app and reused by every AsyncCalculator call.
Future<BcEngine> _openWebEngine() => _webEngineFuture ??= BcLibCWeb.open();

Future<Angular> asyncBarrelElevationForTarget(
  Shot shot,
  Distance targetDistance,
  BcIntegrationMethod method,
  BcConfig config,
) async {
  final engine = await _openWebEngine();
  return calcBarrelElevationForTarget(
    engine,
    method,
    config,
    shot,
    targetDistance,
  );
}

Future<HitResult> asyncFire({
  required Shot shot,
  required Distance trajectoryRange,
  Distance? trajectoryStep,
  required double timeStep,
  required int filterFlags,
  required bool raiseRangeError,
  required BcIntegrationMethod method,
  required BcConfig config,
}) async {
  final engine = await _openWebEngine();
  return calcFire(
    engine,
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
