import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/identity/device_model_channel.dart';

/// The project's second platform channel — F22.
///
/// Same shape as `free_space_channel_test.dart` and the same limitation: the
/// Kotlin half cannot run under `flutter test`, so `Build.MANUFACTURER` and
/// `Build.MODEL` are verified on hardware at step 5's checkpoint. What is
/// testable here is the Dart contract, and specifically the one place this
/// channel deliberately differs from its precedent — a failed read is absence,
/// not an exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('vump/device_model');
  final List<MethodCall> calls = <MethodCall>[];

  void respond(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(calls.clear);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('asks the platform for deviceModel, with no arguments', () async {
    respond((_) => 'OnePlus CPH2707');

    await const DeviceModelChannel(channel: channel).read();

    expect(calls.single.method, 'deviceModel');
    expect(calls.single.arguments, isNull);
  });

  test('returns what the platform reports', () async {
    respond((_) => 'OnePlus CPH2707');

    expect(
      await const DeviceModelChannel(channel: channel).read(),
      'OnePlus CPH2707',
    );
  });

  test('trims surrounding whitespace', () async {
    // `Build.MANUFACTURER` is empty on some images, which makes the Kotlin
    // side's join produce a leading space. Handled on both sides rather than
    // trusting one of them.
    respond((_) => '  Pixel 8  ');

    expect(await const DeviceModelChannel(channel: channel).read(), 'Pixel 8');
  });

  group('absence, not an exception', () {
    test('a platform error yields null', () async {
      respond((_) => throw PlatformException(code: 'UNAVAILABLE'));

      expect(await const DeviceModelChannel(channel: channel).read(), isNull);
    });

    test('an unregistered channel yields null', () async {
      // No handler installed at all — the case on iOS today, and in any test
      // host that binds the composition root.
      const MethodChannel absent = MethodChannel('vump/device_model_absent');

      expect(await const DeviceModelChannel(channel: absent).read(), isNull);
    });

    test('a null reply yields null', () async {
      respond((_) => null);

      expect(await const DeviceModelChannel(channel: channel).read(), isNull);
    });

    test('a blank reply yields null, not a blank model', () async {
      // The important one. An empty string is `MetadataIdentity.unsourced`, so
      // returning it would present "no model" as a sourced value and slip past
      // the composition root's `??`. A-068's Guard 1 must see the blank.
      respond((_) => '   ');

      expect(await const DeviceModelChannel(channel: channel).read(), isNull);
    });
  });
}
