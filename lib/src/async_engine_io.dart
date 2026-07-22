// Native (dart:ffi) backend for AsyncCalculator.
//
// Runs each call on a fresh isolate via Isolate.run, opening its own
// BcLibC engine there — keeps heavy trajectory integration off the
// caller's isolate (e.g. the UI isolate in a Flutter app).

import 'dart:isolate';

import 'package:dart_bclibc/ffi/bclibc_ffi.dart';
import 'package:dart_bclibc/src/calculator.dart';
import 'package:dart_bclibc/src/shot.dart';
import 'package:dart_bclibc/src/trajectory_data.dart';
import 'package:dart_bclibc/src/unit.dart';

Future<Angular> asyncBarrelElevationForTarget(
  Shot shot,
  Distance targetDistance,
  BcIntegrationMethod method,
  BcConfig config,
) => Isolate.run(
  () => Calculator(
    method: method,
    config: config,
  ).barrelElevationForTarget(shot, targetDistance),
);

Future<HitResult> asyncFire({
  required Shot shot,
  required Distance trajectoryRange,
  Distance? trajectoryStep,
  required double timeStep,
  required int filterFlags,
  required bool raiseRangeError,
  required BcIntegrationMethod method,
  required BcConfig config,
}) => Isolate.run(
  () => Calculator(method: method, config: config).fire(
    shot: shot,
    trajectoryRange: trajectoryRange,
    trajectoryStep: trajectoryStep,
    timeStep: timeStep,
    filterFlags: filterFlags,
    raiseRangeError: raiseRangeError,
  ),
);
