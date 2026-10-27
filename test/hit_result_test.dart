import 'package:bclibc/bclibc.dart';
import 'package:test/test.dart';

Shot _shot() {
  final dragModel = DragModel(
    bc: 0.2,
    dragTable: const [(mach: 0.0, cd: 0.2)],
    weight: Weight.grain(100),
    diameter: Distance.inch(0.3),
    length: Distance.inch(1),
  );
  return Shot(
    weapon: Weapon(),
    ammo: Ammo(dm: dragModel, mv: Velocity.fps(2000)),
  );
}

TrajectoryData _record(double time, int flag) => TrajectoryData(
  time: time,
  distance: Distance.foot(time * 100),
  velocity: Velocity.fps(2000 - time),
  mach: 1.5,
  height: Distance.foot(0),
  slantHeight: Distance.foot(0),
  dropAngle: Angular.radian(0),
  windage: Distance.foot(0),
  windageAngle: Angular.radian(0),
  slantDistance: Distance.foot(time * 100),
  angle: Angular.radian(0),
  densityRatio: 1,
  drag: 0.2,
  energy: Energy.footPound(1),
  ogw: Weight.pound(1),
  flag: flag,
);

void main() {
  group('HitResult output views', () {
    final range = TrajFlag.range.value;
    final apex = TrajFlag.apex.value;

    test('keeps exact records and projects coincident events onto samples', () {
      final result = HitResult(_shot(), [
        _record(0, range),
        _record(1, range),
        _record(1, apex),
      ], filterFlags: range | apex);

      expect(result.length, 3);
      expect(result.toList(), result.records);
      expect(result[2].flag, apex);
      expect(result.events, hasLength(1));
      expect(result.events.single.flag, apex);
      expect(result.samples, hasLength(2));
      expect(result.samples.last.flag, range | apex);
      expect(result.flag(TrajFlag.apex), result.events.single);
    });

    test(
      'does not attach a distinct event to the nearest scheduled sample',
      () {
        final result = HitResult(_shot(), [
          _record(0, range),
          _record(0.5, apex),
          _record(1, range),
        ], filterFlags: range | apex);

        expect(result.samples.map((row) => row.flag), [range, range]);
        expect(result.events.single.flag, apex);
      },
    );

    test('rejects lookups for unrequested flags', () {
      final result = HitResult(_shot(), [
        _record(0, range),
      ], filterFlags: range);

      expect(() => result.flag(TrajFlag.apex), throwsStateError);
    });
  });
}
