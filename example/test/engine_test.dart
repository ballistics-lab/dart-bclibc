import 'package:bclibc/bclibc.dart';
import 'package:bclibc_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` is where the build hook has to hand the native library over.
  test('the native engine loads and computes under flutter test', () {
    expect(BcLibC.open().calculateEnergy(168.0, 2700.0), greaterThan(0));
  });

  test('AsyncCalculator solves a 500 m shot', () async {
    final mil = await elevationMil();
    expect(mil.isFinite, isTrue);
    expect(mil, greaterThan(0));
  });
}
