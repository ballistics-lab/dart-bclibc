// Default BcConfig, shared by Calculator (native) and AsyncCalculator
// (native + web) — kept platform-agnostic (no dart:ffi/dart:io/js_interop
// imports) so AsyncCalculator's web path doesn't have to pull in
// calculator.dart just for this constant.

import 'package:dart_bclibc/ffi/bclibc_types.dart';
import 'package:dart_bclibc/src/constants.dart';

// ---------------------------------------------------------------------------
// Default config constants (mirror TS DEFAULT_CONFIG)
// ---------------------------------------------------------------------------

const double cZeroFindingAccuracy = 0.000005;
const int cMaxIterations = 40;
const double cMinimumAltitude = -1500.0;
const double cMaximumDrop = -10000.0;
const double cMinimumVelocity = 50.0;
const double cGravityConstant = -BallisticConstants.cGravityImperial;
const double cStepMultiplier = 1.0;

const BcConfig defaultConfig = BcConfig(
  zeroFindingAccuracy: cZeroFindingAccuracy,
  maxIterations: cMaxIterations,
  minimumAltitude: cMinimumAltitude,
  maximumDrop: cMaximumDrop,
  minimumVelocity: cMinimumVelocity,
  gravityConstant: cGravityConstant,
  stepMultiplier: cStepMultiplier,
);
