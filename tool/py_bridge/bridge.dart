// JSON-lines bridge between py-ballisticcalc and dart-bclibc.
//
// Lets py-ballisticcalc's own test suite drive this package: the Python engine
// in python/ (`dart_bclibc`) spawns this program once and sends one JSON
// request per line on stdin; each is answered by one JSON line on stdout.
//
// A request carries a py-ballisticcalc `Shot` in plain numbers, which is rebuilt
// here as the package's own `Shot` (Atmo, Ammo/DragModel, Weapon, Wind...) and
// converted by the same `toBcShot` / `toTrajectoryData` the Calculator uses, so
// the Dart value types and the FFI layer are exercised, not only the C library.
// Quantities are exchanged in feet / fps / radians / grains / pounds / Celsius /
// hPa, the units bclibc works in. NaN and infinity travel as null.
//
//   {"id":1,"op":"integrate","method":"rk4","config":{...},"shot":{...},
//    "range_ft":..,"step_ft":..,"time_step":..,"flags":..}
//   {"id":2,"op":"zero_point","method":"rk4","config":{...},"shot":{...},"distance_ft":..}
//   {"id":3,"op":"zero_angle", ...same...}
//   {"id":4,"op":"max_range","method":..,"config":..,"shot":..,"low_deg":..,"high_deg":..}
//   {"id":5,"op":"apex", ...shot...}
//   {"id":6,"op":"info"}
//
// Replies: {"id":N,"ok":true,"result":{...}} or
//          {"id":N,"ok":false,"error":{"kind":"out_of_range|zero_finding|solver|dart",...}}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bclibc/ffi/bclibc_ffi.dart';
import 'package:bclibc/src/calculator_core.dart';
import 'package:bclibc/src/conditions.dart';
import 'package:bclibc/src/drag_model.dart';
import 'package:bclibc/src/munition.dart';
import 'package:bclibc/src/shot.dart';
import 'package:bclibc/src/trajectory_data.dart';
import 'package:bclibc/src/unit.dart';

double _d(Object? v) => (v as num).toDouble();

double? _dn(Object? v) => v == null ? null : (v as num).toDouble();

Object? _out(double v) => v.isFinite ? v : null;

BcConfig _config(Map<String, dynamic> j) => BcConfig(
  stepMultiplier: _d(j['step_multiplier']),
  zeroFindingAccuracy: _d(j['zero_finding_accuracy']),
  minimumVelocity: _d(j['minimum_velocity']),
  maximumDrop: _d(j['maximum_drop']),
  maxIterations: (j['max_iterations'] as num).toInt(),
  gravityConstant: _d(j['gravity_constant']),
  minimumAltitude: _d(j['minimum_altitude']),
);

BcIntegrationMethod _method(String name) => switch (name) {
  'rk4' => BcIntegrationMethod.rk4,
  'euler' => BcIntegrationMethod.euler,
  'verlet' => BcIntegrationMethod.velocityVerlet,
  'rkck' => BcIntegrationMethod.rkck,
  'dopri' => BcIntegrationMethod.dopri,
  'tsitouras' => BcIntegrationMethod.tsitouras,
  _ => throw ArgumentError('Unknown integration method: $name'),
};

Shot _shot(Map<String, dynamic> j) {
  final ammo = j['ammo'] as Map<String, dynamic>;
  final atmo = j['atmo'] as Map<String, dynamic>;
  final weapon = j['weapon'] as Map<String, dynamic>;
  final dm = ammo['dm'] as Map<String, dynamic>;

  final dragTable = [
    for (final p in dm['drag_table'] as List)
      {'mach': _d((p as List)[0]), 'cd': _d(p[1])},
  ];

  final winds = <Wind>[
    for (final w in (j['winds'] as List))
      Wind(
        velocity: Velocity.fps(_d((w as Map)['velocity_fps'])),
        directionFrom: Angular.radian(_d(w['direction_from_rad'])),
        untilDistance: Distance.foot(_d(w['until_distance_ft'])),
      ),
  ];

  return Shot(
    weapon: Weapon(
      sightHeight: Distance.foot(_d(weapon['sight_height_ft'])),
      twist: Distance.inch(_d(weapon['twist_inch'])),
      zeroElevation: Angular.radian(_d(weapon['zero_elevation_rad'])),
    ),
    ammo: Ammo(
      dm: DragModel(
        bc: _d(dm['bc']),
        dragTable: dragTable,
        weight: Weight.grain(_d(dm['weight_grain'])),
        diameter: Distance.inch(_d(dm['diameter_inch'])),
        length: Distance.inch(_d(dm['length_inch'])),
      ),
      mv: Velocity.fps(_d(ammo['mv_fps'])),
      powderTemp: Temperature.celsius(_d(ammo['powder_temp_c'])),
      tempModifier: _d(ammo['temp_modifier']),
      usePowderSensitivity: ammo['use_powder_sensitivity'] as bool,
    ),
    atmo: Atmo(
      altitude: Distance.foot(_d(atmo['altitude_ft'])),
      pressure: Pressure.hPa(_d(atmo['pressure_hpa'])),
      temperature: Temperature.celsius(_d(atmo['temperature_c'])),
      humidity: _d(atmo['humidity']),
      powderTemperature: Temperature.celsius(_d(atmo['powder_temp_c'])),
    ),
    lookAngle: Angular.radian(_d(j['look_angle_rad'])),
    relativeAngle: Angular.radian(_d(j['relative_angle_rad'])),
    cantAngle: Angular.radian(_d(j['cant_angle_rad'])),
    winds: winds,
    azimuthDeg: _dn(j['azimuth_deg']),
    latitudeDeg: _dn(j['latitude_deg']),
  );
}

// Order matches TRAJECTORY_FIELDS in python/src/dart_bclibc/pybc.py.
List<Object?> _row(TrajectoryData d) => [
  _out(d.time),
  _out(d.distance.in_(Unit.foot)),
  _out(d.velocity.in_(Unit.fps)),
  _out(d.mach),
  _out(d.height.in_(Unit.foot)),
  _out(d.slantHeight.in_(Unit.foot)),
  _out(d.dropAngle.in_(Unit.radian)),
  _out(d.windage.in_(Unit.foot)),
  _out(d.windageAngle.in_(Unit.radian)),
  _out(d.slantDistance.in_(Unit.foot)),
  _out(d.angle.in_(Unit.radian)),
  _out(d.densityRatio),
  _out(d.drag),
  _out(d.energy.in_(Unit.footPound)),
  _out(d.ogw.in_(Unit.pound)),
  d.flag,
];

Map<String, Object?> _handle(BcEngine engine, Map<String, dynamic> req) {
  final op = req['op'] as String;
  if (op == 'info') {
    return {'methods': BcIntegrationMethod.values.map((m) => m.name).toList()};
  }

  final method = _method(req['method'] as String);
  final config = _config(req['config'] as Map<String, dynamic>);
  final shot = _shot(req['shot'] as Map<String, dynamic>);

  switch (op) {
    case 'integrate':
      final result = engine.integrateShot(
        toBcShot(shot, method, config),
        BcTrajectoryRequest(
          rangeLimitFt: _d(req['range_ft']),
          rangeStepFt: _d(req['step_ft']),
          timeStep: _d(req['time_step']),
          filterFlags: (req['flags'] as num).toInt(),
        ),
      );
      return {
        'reason': result.reason.value,
        'rows': result.trajectory
            .map((r) => _row(toTrajectoryData(r)))
            .toList(),
      };
    case 'zero_point':
      final r = engine.findZeroPointShot(
        toBcShot(shot, method, config),
        _d(req['distance_ft']),
      );
      return {
        'angle_rad': r.angleRad,
        'point': _row(toTrajectoryData(r.point)),
      };
    case 'zero_angle':
      return {
        'angle_rad': engine.findZeroAngleShot(
          toBcShot(shot, method, config),
          _d(req['distance_ft']),
        ),
      };
    case 'max_range':
      final r = engine.findMaxRangeShot(
        toBcShot(shot, method, config),
        lowAngleDeg: _d(req['low_deg']),
        highAngleDeg: _d(req['high_deg']),
      );
      return {'max_range_ft': r.maxRangeFt, 'angle_rad': r.angleAtMaxRad};
    case 'apex':
      return {
        'point': _row(
          toTrajectoryData(engine.findApexShot(toBcShot(shot, method, config))),
        ),
      };
    default:
      throw ArgumentError('Unknown op: $op');
  }
}

Map<String, Object?> _error(Object e) {
  if (e is BcException) {
    return {
      'kind': switch (e.code) {
        2 => 'out_of_range',
        3 => 'zero_finding',
        _ => 'solver',
      },
      'code': e.code,
      'message': e.message,
      'requested_distance_ft': e.requestedDistanceFt,
      'max_range_ft': e.maxRangeFt,
      'look_angle_rad': e.lookAngleRad,
      'zero_finding_error': e.zeroFindingError,
      'last_barrel_elevation_rad': e.lastBarrelElevationRad,
      'iterations_count': e.iterationsCount,
    };
  }
  return {'kind': 'dart', 'type': e.runtimeType.toString(), 'message': '$e'};
}

Future<void> main() async {
  // stdout is the protocol channel; anything the library prints goes to stderr.
  final out = stdout;
  await runZoned(
    () async {
      final engine = BcLibC.open();
      await for (final line
          in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        Object? id;
        Map<String, Object?> reply;
        try {
          final req = jsonDecode(line) as Map<String, dynamic>;
          id = req['id'];
          reply = {'id': id, 'ok': true, 'result': _handle(engine, req)};
        } on Object catch (e) {
          reply = {'id': id, 'ok': false, 'error': _error(e)};
        }
        out.writeln(jsonEncode(reply));
        await out.flush();
      }
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => stderr.writeln(line),
    ),
  );
}
