import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/battery_plus_battery_reader.dart';
import 'package:mocktail/mocktail.dart';

class _MockBattery extends Mock implements Battery {}

/// The `battery_plus` adapter, which had no test until Mission 8.1.
///
/// It is four lines of delegation wrapped in one conversion, and the
/// conversion is the whole point: ADR-025 §7 requires a third-party failure to
/// be converted at the module that owns the package, so nothing above this
/// layer ever names a `PlatformException`. The file's own comment records that
/// the plugin *"throws a PlatformException on some devices and a bare
/// `Exception` on others"* — which is why the catch is `on Object` and why the
/// tests below throw two different shapes at it rather than one.
void main() {
  late _MockBattery battery;
  late BatteryPlusBatteryReader reader;

  setUp(() {
    battery = _MockBattery();
    reader = BatteryPlusBatteryReader(battery: battery);
  });

  test('reports the level the platform reports', () async {
    when(() => battery.batteryLevel).thenAnswer((_) async => 87);

    expect(await reader.percent(), 87);
  });

  test('passes the boundary values through rather than clamping', () async {
    // FR-CHK-03 gates recording at 20%, and the gate lives in the checklist,
    // not here. A reader that clamped would hide a real 0.
    when(() => battery.batteryLevel).thenAnswer((_) async => 0);
    expect(await reader.percent(), 0);

    when(() => battery.batteryLevel).thenAnswer((_) async => 100);
    expect(await reader.percent(), 100);
  });

  group('whatever shape the failure arrives in', () {
    test('an Exception converts to deviceBatteryUnreadable', () async {
      final Exception cause = Exception('no battery service');
      when(() => battery.batteryLevel).thenThrow(cause);

      await expectLater(
        reader.percent,
        throwsA(
          isA<DeviceException>()
              .having(
                (DeviceException e) => e.errorCode,
                'errorCode',
                ErrorCode.deviceBatteryUnreadable,
              )
              .having((DeviceException e) => e.cause, 'cause', cause),
        ),
      );
    });

    test('an Error converts too, because the catch is on Object', () async {
      // The distinction matters: `on Exception` would let a StateError escape
      // as itself and reach the checklist as an unconverted platform failure.
      when(() => battery.batteryLevel).thenThrow(StateError('channel closed'));

      await expectLater(
        reader.percent,
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.errorCode,
            'errorCode',
            ErrorCode.deviceBatteryUnreadable,
          ),
        ),
      );
    });

    test('the message says what could not be read, not how', () async {
      when(() => battery.batteryLevel).thenThrow(Exception('x'));

      try {
        await reader.percent();
        fail('percent should have thrown');
      } on DeviceException catch (error) {
        expect(error.message, 'The battery level could not be read.');
      }
    });
  });
}
