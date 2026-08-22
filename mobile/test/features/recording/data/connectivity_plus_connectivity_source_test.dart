import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/connectivity/connectivity_status.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/connectivity_plus_connectivity_source.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// `watch()`'s two obligations, neither of which had a test until Mission 8.1.
///
/// Both are stated in the file's own comments and both are the kind of
/// behaviour that fails silently. The first emission happens *before* any
/// platform event, so a dispatcher subscribing while already online starts
/// immediately rather than waiting *"for a transition that may never come"*.
/// And duplicates are suppressed, because the platform reports interface
/// reshuffles that both reduce to `online` — a Wi-Fi to cellular hand-off —
/// and re-emitting those *"would have the dispatcher treat a steady connection
/// as a stream of reconnections"*.
void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> platform;
  late ConnectivityPlusConnectivitySource source;

  setUp(() {
    connectivity = _MockConnectivity();
    platform = StreamController<List<ConnectivityResult>>();
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => platform.stream);
    source = ConnectivityPlusConnectivitySource(connectivity: connectivity);
  });

  tearDown(() {
    // NOT `tearDown(() => platform.close())`. A non-broadcast controller's
    // `close()` future does not complete until its done event is delivered,
    // which needs a listener — and `take(1)` has already cancelled by then.
    // Returning that future makes tearDown await something that never
    // completes, and the suite reports it as the TEST timing out.
    unawaited(platform.close());
  });

  void startAt(List<ConnectivityResult> results) {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => results);
  }

  test('emits the current status before any platform event arrives', () async {
    startAt(<ConnectivityResult>[ConnectivityResult.wifi]);

    await expectLater(
      source.watch().take(1),
      emitsInOrder(<ConnectivityStatus>[ConnectivityStatus.online]),
    );
  });

  test('an offline start emits offline first, not nothing', () async {
    startAt(<ConnectivityResult>[ConnectivityResult.none]);

    await expectLater(
      source.watch().take(1),
      emitsInOrder(<ConnectivityStatus>[ConnectivityStatus.offline]),
    );
  });

  test('suppresses a change that reduces to the same status', () async {
    startAt(<ConnectivityResult>[ConnectivityResult.wifi]);

    final Future<List<ConnectivityStatus>> collected = source
        .watch()
        .take(2)
        .toList();

    // A Wi-Fi to cellular hand-off: a real platform event, and still online.
    platform.add(<ConnectivityResult>[ConnectivityResult.mobile]);
    // Only this one is a genuine transition.
    platform.add(<ConnectivityResult>[ConnectivityResult.none]);

    expect(await collected, <ConnectivityStatus>[
      ConnectivityStatus.online,
      ConnectivityStatus.offline,
    ]);
  });

  test('emits again when the status genuinely flips back', () async {
    startAt(<ConnectivityResult>[ConnectivityResult.none]);

    final Future<List<ConnectivityStatus>> collected = source
        .watch()
        .take(3)
        .toList();

    platform.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    platform.add(<ConnectivityResult>[ConnectivityResult.none]);

    expect(await collected, <ConnectivityStatus>[
      ConnectivityStatus.offline,
      ConnectivityStatus.online,
      ConnectivityStatus.offline,
    ]);
  });

  test(
    'current() converts a platform failure rather than leaking it',
    () async {
      when(() => connectivity.checkConnectivity()).thenThrow(Exception('down'));

      await expectLater(
        source.current,
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.errorCode,
            'errorCode',
            ErrorCode.deviceNetworkStatusUnreadable,
          ),
        ),
      );
    },
  );
}
