// Runs on a real device/emulator (CI: Android emulator): the library the build
// hook compiled has to be loadable and compute there, not just be present in
// the APK.
import 'package:bclibc/bclibc.dart';
import 'package:bclibc_example/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('BcLibC.open() loads the native library on the device', () {
    expect(BcLibC.open().calculateEnergy(168.0, 2700.0), greaterThan(0));
  });

  test('AsyncCalculator solves a shot on the device', () async {
    final mil = await elevationMil();
    expect(mil.isFinite, isTrue);
    expect(mil, greaterThan(0));
  });
}
