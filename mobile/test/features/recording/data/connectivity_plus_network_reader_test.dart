import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/connectivity_plus_network_reader.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// The reduction from the platform's interface LIST to Chapter 4.5's three
/// spellings, untested until Mission 8.1.
///
/// This is the file's only real logic and every branch of it is a judgement:
/// `ethernet` and `vpn` are folded into `wifi` because Volume 4 Chapter 4.5
/// fixes the stored vocabulary at three values and both are unmetered
/// connections an upload starts on immediately, *"which is the only
/// distinction FR-CHK-04 draws"*. A mapping table nothing asserts is a table
/// that can be rewritten by accident, so each row is pinned.
void main() {
  late _MockConnectivity connectivity;
  late ConnectivityPlusNetworkReader reader;

  setUp(() {
    connectivity = _MockConnectivity();
    reader = ConnectivityPlusNetworkReader(connectivity: connectivity);
  });

  Future<NetworkType> readWith(List<ConnectivityResult> results) {
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => results);
    return reader.current();
  }

  group('the unmetered kinds all read as wifi', () {
    for (final ConnectivityResult result in <ConnectivityResult>[
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
    ]) {
      test('${result.name} reduces to wifi', () async {
        expect(await readWith(<ConnectivityResult>[result]), NetworkType.wifi);
      });
    }
  });

  group('the metered and unknown kinds all read as cellular', () {
    for (final ConnectivityResult result in <ConnectivityResult>[
      ConnectivityResult.mobile,
      ConnectivityResult.other,
      ConnectivityResult.bluetooth,
    ]) {
      test('${result.name} reduces to cellular', () async {
        expect(
          await readWith(<ConnectivityResult>[result]),
          NetworkType.cellular,
        );
      });
    }
  });

  test('no interface, and an empty list, both read as none', () async {
    expect(
      await readWith(<ConnectivityResult>[ConnectivityResult.none]),
      NetworkType.none,
    );
    expect(await readWith(<ConnectivityResult>[]), NetworkType.none);
  });

  test('wifi wins when both are present, not the first in the list', () async {
    // The platform reports a list, and a phone on Wi-Fi with mobile data up
    // reports both. Order is the platform's business; the verdict is not.
    expect(
      await readWith(<ConnectivityResult>[
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
      ]),
      NetworkType.wifi,
    );
    expect(
      await readWith(<ConnectivityResult>[
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]),
      NetworkType.wifi,
    );
  });

  test(
    'a platform failure converts to deviceNetworkStatusUnreadable',
    () async {
      final Exception cause = Exception('connectivity channel unavailable');
      when(() => connectivity.checkConnectivity()).thenThrow(cause);

      await expectLater(
        reader.current,
        throwsA(
          isA<DeviceException>()
              .having(
                (DeviceException e) => e.errorCode,
                'errorCode',
                ErrorCode.deviceNetworkStatusUnreadable,
              )
              .having((DeviceException e) => e.cause, 'cause', cause),
        ),
      );
    },
  );
}
