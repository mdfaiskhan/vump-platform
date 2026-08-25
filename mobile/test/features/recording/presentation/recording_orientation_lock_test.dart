import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/presentation/recording_orientation_lock.dart';

/// The counter exists for one reason, and this file is that reason.
///
/// Flutter builds the incoming route before disposing the outgoing one, so the
/// Recording screen acquires the lock BEFORE the Checklist releases it. A
/// set-on-enter / restore-on-exit pair would drop the window back to portrait
/// mid-flow — and because the camera plugin bakes the display rotation in at
/// creation time, that is exactly the stale-rotation window ADR-054's third
/// amendment removes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            calls.add(call);
          }
          return null;
        });
    await RecordingOrientationLock.resetForTest();
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> orientationsOf(MethodCall call) =>
      (call.arguments as List<Object?>).cast<String>();

  group('the flow holds landscape across a screen handover', () {
    test('the first acquire rotates to landscape', () async {
      await RecordingOrientationLock.acquire();

      expect(RecordingOrientationLock.holders, 1);
      expect(calls, hasLength(1));
      expect(orientationsOf(calls.single), <String>[
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    });

    test(
      'a second acquire changes nothing — no redundant platform call',
      () async {
        await RecordingOrientationLock.acquire();
        calls.clear();

        await RecordingOrientationLock.acquire();

        expect(RecordingOrientationLock.holders, 2);
        expect(calls, isEmpty);
      },
    );

    test('the REAL ordering keeps landscape held throughout', () async {
      // Checklist mounts, Recording screen mounts, Checklist disposes LAST.
      // That is Flutter's actual order, and the whole reason for the counter.
      await RecordingOrientationLock.acquire(); // checklist initState
      await RecordingOrientationLock.acquire(); // recording initState
      calls.clear();

      await RecordingOrientationLock.release(); // checklist dispose, late

      expect(RecordingOrientationLock.holders, 1);
      expect(
        calls,
        isEmpty,
        reason: 'the late dispose must not rotate back to portrait',
      );
    });

    test('portrait returns only when the last holder releases', () async {
      await RecordingOrientationLock.acquire();
      await RecordingOrientationLock.acquire();
      await RecordingOrientationLock.release();
      calls.clear();

      await RecordingOrientationLock.release();

      expect(RecordingOrientationLock.holders, 0);
      expect(calls, hasLength(1));
      expect(orientationsOf(calls.single), <String>[
        'DeviceOrientation.portraitUp',
      ]);
    });
  });

  group('it cannot be driven negative', () {
    test('releasing with no holders is a no-op, not an underflow', () async {
      // A screen disposed twice, or a release racing a reset, must not leave
      // the counter negative — the next acquire would then fail to rotate.
      await RecordingOrientationLock.release();

      expect(RecordingOrientationLock.holders, 0);
      expect(calls, isEmpty);

      await RecordingOrientationLock.acquire();

      expect(RecordingOrientationLock.holders, 1);
      expect(calls, hasLength(1));
    });
  });

  group('the orientation sets themselves', () {
    test('landscape is the two landscapes, never portrait', () {
      // All four would map to SCREEN_ORIENTATION_FULL_USER, which respects the
      // handset's auto-rotate setting and so fails to rotate at all when that
      // is off. These two map to USER_LANDSCAPE, which forces landscape.
      expect(RecordingOrientationLock.landscape, <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('portrait is upright only', () {
      expect(RecordingOrientationLock.portrait, <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    });
  });
}
