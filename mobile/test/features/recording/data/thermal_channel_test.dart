import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/thermal_channel.dart';

/// Migration 0017's channel, and the boundary that refuses to fail a chunk.
///
/// The Kotlin half cannot be exercised from `flutter test`; it is verified on
/// hardware. What is testable here is the Dart contract: the method name sent,
/// the type received, and that **no failure escapes as an exception** — the
/// property that separates this channel from `FreeSpaceChannel`, where a
/// failure must stop the pipeline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('vump/thermal');
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

  group('the channel name', () {
    test(
      'the default constructor talks to the channel this test names',
      () async {
        // Deliberately the DEFAULT constructor, for the reason
        // `free_space_channel_test.dart` records at length: every other test
        // here injects a channel, so a renamed `_defaultChannel` would go
        // unnoticed. A mock handler is registered against a channel's NAME, so
        // if the production default stops matching the literal above, this call
        // reaches no handler and returns null instead of 4.
        respond((MethodCall call) => 4);

        expect(await const ThermalChannel().currentThermalState(), 4);
        expect(calls.single.method, 'currentThermalStatus');
      },
    );
  });

  group('the value', () {
    test('passes the platform integer through untranslated', () async {
      respond((MethodCall call) => 3);

      expect(
        await const ThermalChannel(channel: channel).currentThermalState(),
        3,
      );
    });

    test('preserves zero, which is a reading and not an absence', () async {
      // THERMAL_STATUS_NONE is 0 and means the device is cool. A boundary that
      // collapsed it to null would erase the difference between a device that
      // reported it was fine and one that reported nothing at all — the same
      // distinction migration 0017's nullable column exists to keep.
      respond((MethodCall call) => 0);

      expect(
        await const ThermalChannel(channel: channel).currentThermalState(),
        0,
      );
    });

    test('reports null when the platform itself answers null', () async {
      // What the Kotlin half returns below API 29.
      respond((MethodCall call) => null);

      expect(
        await const ThermalChannel(channel: channel).currentThermalState(),
        isNull,
      );
    });
  });

  group('every failure resolves to null, and nothing escapes', () {
    test('a platform error becomes null rather than an exception', () async {
      respond((MethodCall call) => throw PlatformException(code: 'BOOM'));

      expect(
        await const ThermalChannel(channel: channel).currentThermalState(),
        isNull,
      );
    });

    test('an unregistered native half becomes null too', () async {
      // A packaging fault rather than a device limitation, and the one case
      // this deliberately masks. The alternative is failing chunk
      // finalization on a build that forgot to register a channel, which
      // turns a missing optional field into lost footage.
      respond((MethodCall call) => throw MissingPluginException('absent'));

      expect(
        await const ThermalChannel(channel: channel).currentThermalState(),
        isNull,
      );
    });

    test('no PlatformException reaches the caller', () async {
      respond((MethodCall call) => throw PlatformException(code: 'BOOM'));

      // The contract `ThermalStateReader` states, asserted rather than
      // assumed: a thermal read must never fail a chunk.
      await expectLater(
        const ThermalChannel(channel: channel).currentThermalState(),
        completes,
      );
    });
  });
}
