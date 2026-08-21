import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/data/free_space_channel.dart';

/// The project's first platform channel, and its conversion boundary.
///
/// The native halves cannot be exercised from `flutter test` — the Android
/// side is verified on hardware and recorded in A-058, the iOS side has never
/// run. What is testable here is the Dart contract: the payload sent, the
/// type received, and that nothing platform-specific escapes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('vump/free_space');
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
        // **Deliberately the DEFAULT constructor.** Every other test here
        // injects `channel`, so the production `_defaultChannel` is never
        // exercised and its name is never checked — Mission 7.10's mutation
        // sweep renamed it and all ten tests still passed.
        //
        // `_defaultChannel` is private and cannot be read from here. It can be
        // EXERCISED: a mock handler is registered against a channel's NAME, so
        // if the production default stops matching the literal at the top of
        // this file, this call reaches no handler, raises a
        // MissingPluginException and converts to StorageException. The two
        // literals are tied by
        // behaviour rather than by comparison.
        //
        // The name is a contract with native code that cannot be exercised from
        // `flutter test` at all — Android is verified on hardware (A-058), iOS
        // has never run — so this is the only side of it a test can hold.
        respond((MethodCall call) => 4096);

        expect(await const FreeSpaceChannel().availableBytes('/docs'), 4096);
      },
    );
  });

  group('the request', () {
    test('sends the path the caller asked about', () async {
      respond((_) => 1234);

      await const FreeSpaceChannel(channel: channel).availableBytes('/docs');

      expect(calls.single.method, 'availableBytes');
      expect(calls.single.arguments, <String, Object?>{'path': '/docs'});
    });
  });

  group('the response is bytes, as an int', () {
    test('a plain byte count comes back unchanged', () async {
      respond((_) => 12345678901);

      final int bytes = await const FreeSpaceChannel(
        channel: channel,
      ).availableBytes('/docs');

      expect(bytes, 12345678901);
      expect(bytes, isA<int>());
    });

    test('a value beyond 32-bit range survives', () async {
      // 50 GB. The packages this channel replaced return megabytes through a
      // float32 division; asserting a large exact integer is what pins the
      // difference.
      const int fiftyGb = 50 * 1000 * 1000 * 1000;
      respond((_) => fiftyGb);

      expect(
        await const FreeSpaceChannel(channel: channel).availableBytes('/docs'),
        fiftyGb,
      );
    });
  });

  group('the conversion boundary', () {
    test('a platform error becomes a StorageException', () async {
      respond((_) => throw PlatformException(code: 'STAT_FAILED'));

      await expectLater(
        const FreeSpaceChannel(channel: channel).availableBytes('/docs'),
        throwsA(
          isA<StorageException>().having(
            (StorageException e) => e.errorCode,
            'errorCode',
            ErrorCode.storageUnavailable,
          ),
        ),
      );
    });

    test('an unregistered channel becomes a StorageException too', () async {
      // MissingPluginException means the native half is absent — a packaging
      // fault. It must not escape as a Flutter type.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      Object? caught;
      try {
        await const FreeSpaceChannel(channel: channel).availableBytes('/docs');
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isA<StorageException>());
      expect(caught, isNot(isA<MissingPluginException>()));
    });

    test('a null reading is refused rather than defaulted', () async {
      // Defaulting to zero would force an immediate early boundary; defaulting
      // to a large number would mask a full disk. Neither is safe, so it
      // raises.
      respond((_) => null);

      await expectLater(
        const FreeSpaceChannel(channel: channel).availableBytes('/docs'),
        throwsA(isA<StorageException>()),
      );
    });

    test('no PlatformException escapes the boundary', () async {
      respond((_) => throw PlatformException(code: 'anything'));

      Object? caught;
      try {
        await const FreeSpaceChannel(channel: channel).availableBytes('/docs');
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isNot(isA<PlatformException>()));
    });
  });
}
