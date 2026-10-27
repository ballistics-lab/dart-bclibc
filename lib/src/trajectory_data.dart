import 'dart:math' as math;

import 'package:bclibc/src/unit.dart';
import 'package:bclibc/src/shot.dart';

enum TrajFlag {
  none(0),
  zeroUp(1),
  zeroDown(2),
  zero(3),
  mach(4),
  range(8),
  apex(16),
  mrt(32);

  final int value;
  const TrajFlag(this.value);

  static String getName(int flagValue) {
    if (flagValue == 0) return "NONE";
    List<String> parts = [];
    if (flagValue & zeroUp.value != 0) parts.add("ZERO_UP");
    if (flagValue & zeroDown.value != 0) parts.add("ZERO_DOWN");
    if (flagValue & mach.value != 0) parts.add("MACH");
    if (flagValue & range.value != 0) parts.add("RANGE");
    if (flagValue & apex.value != 0) parts.add("APEX");
    return parts.isEmpty ? "UNKNOWN" : parts.join("|");
  }
}

class TrajectoryData {
  final double time;
  final Distance distance;
  final Velocity velocity;
  final double mach;
  final Distance height;
  final Distance slantHeight;
  final Angular dropAngle;
  final Distance windage;
  final Angular windageAngle;
  final Distance slantDistance;
  final Angular angle;
  final double densityRatio;
  final double drag;
  final Energy energy;
  final Weight ogw;
  final int flag;

  TrajectoryData({
    required this.time,
    required this.distance,
    required this.velocity,
    required this.mach,
    required this.height,
    required this.slantHeight,
    required this.dropAngle,
    required this.windage,
    required this.windageAngle,
    required this.slantDistance,
    required this.angle,
    required this.densityRatio,
    required this.drag,
    required this.energy,
    required this.ogw,
    required this.flag,
  });

  List<String> formatted() {
    return [
      "${time.toStringAsFixed(3)} s",
      distance.toString(),
      velocity.toString(),
      "${mach.toStringAsFixed(2)} mach",
      height.toString(),
      windage.toString(),
      dropAngle.toString(),
      TrajFlag.getName(flag),
    ];
  }

  TrajectoryData copyWithFlag(int flag) => TrajectoryData(
    time: time,
    distance: distance,
    velocity: velocity,
    mach: mach,
    height: height,
    slantHeight: slantHeight,
    dropAngle: dropAngle,
    windage: windage,
    windageAngle: windageAngle,
    slantDistance: slantDistance,
    angle: angle,
    densityRatio: densityRatio,
    drag: drag,
    energy: energy,
    ogw: ogw,
    flag: flag,
  );
}

class HitResult extends Iterable<TrajectoryData> {
  static final _eventFlags =
      TrajFlag.zero.value |
      TrajFlag.mach.value |
      TrajFlag.apex.value |
      TrajFlag.mrt.value;
  static const _sameInstantRelativeTolerance = 1e-3;
  static const _sameInstantAbsoluteTolerance = 1e-6;

  final Shot shot;
  final List<TrajectoryData> records;
  final int filterFlags;
  final Exception? error;

  HitResult(
    this.shot,
    List<TrajectoryData> records, {
    this.filterFlags = 0,
    this.error,
  }) : records = List.unmodifiable(records);

  /// Exact physical event roots (ZERO, MACH, APEX, and MRT).
  late final List<TrajectoryData> events = List.unmodifiable(
    records.where((row) => (row.flag & _eventFlags) != 0),
  );

  /// Scheduled samples, with an event flag attached only at the same instant.
  late final List<TrajectoryData> samples = _buildSamples();

  @Deprecated('Use records for exact results or samples for scheduled output.')
  List<TrajectoryData> get trajectory => records;

  @override
  int get length => records.length;

  @override
  Iterator<TrajectoryData> get iterator => records.iterator;

  TrajectoryData operator [](int index) => records[index];

  List<TrajectoryData> _buildSamples() {
    final scheduled = records
        .where(
          (row) =>
              (row.flag & TrajFlag.range.value) != 0 ||
              (row.flag & _eventFlags) == 0,
        )
        .toList();
    if (scheduled.isEmpty) return const [];

    final projected = List<TrajectoryData>.of(scheduled);
    for (final event in events) {
      final index = _nearestSampleIndex(scheduled, event.time);
      if (_isSameInstant(scheduled[index].time, event.time)) {
        final sample = projected[index];
        projected[index] = sample.copyWithFlag(sample.flag | event.flag);
      }
    }
    return List.unmodifiable(projected);
  }

  int _nearestSampleIndex(List<TrajectoryData> scheduled, double time) {
    var right = 0;
    while (right < scheduled.length && scheduled[right].time < time) {
      right++;
    }
    if (right == 0) return 0;
    if (right == scheduled.length) return scheduled.length - 1;
    final left = right - 1;
    return time - scheduled[left].time < scheduled[right].time - time
        ? left
        : right;
  }

  bool _isSameInstant(double first, double second) {
    final difference = (first - second).abs();
    return difference <= _sameInstantAbsoluteTolerance ||
        difference <=
            _sameInstantRelativeTolerance * math.max(first.abs(), second.abs());
  }

  void _checkFlag(TrajFlag requested) {
    if ((filterFlags & requested.value) == 0) {
      throw StateError(
        '${TrajFlag.getName(requested.value)} was not requested in trajectory.',
      );
    }
  }

  /// Returns the first exact row matching [requested], or null when absent.
  TrajectoryData? flag(TrajFlag requested) {
    _checkFlag(requested);
    final rows = (requested.value & _eventFlags) != 0 ? events : records;
    for (final row in rows) {
      if ((row.flag & requested.value) != 0) return row;
    }
    return null;
  }

  TrajectoryData getAtDistance(Distance d) {
    final target = d.in_(Unit.foot);
    final index = records.indexWhere(
      (step) => step.distance.in_(Unit.foot) >= target,
    );
    if (index == -1) {
      return records.last;
    }
    return records[index];
  }

  List<TrajectoryData> get zeros {
    _checkFlag(TrajFlag.zero);
    final result = events
        .where((step) => (step.flag & TrajFlag.zero.value) != 0)
        .toList();
    if (result.isEmpty) throw StateError("Can't find zero crossing points");
    return List.unmodifiable(result);
  }
}
