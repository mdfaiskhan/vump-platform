import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:mobile/core/connectivity/connectivity_status.dart';
import 'package:mobile/core/connectivity/interfaces/connectivity_source.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';

/// Volume 5 Chapter 5.12 §2's ConnectivityService, over `connectivity_plus`.
///
/// ## Why this lives in `features/recording/data/`
///
/// It does not belong here on any reading of what it does — the consumer is
/// `features/upload/`, and Chapter 5.12 §2 calls it a service for *"the rest
/// of the app"*. It lives here because `connectivity_plus` is confined here by
/// the `Architecture boundaries` job, and moving the package would mean
/// editing the Pre-Recording Checklist path that Mission 3 verified on
/// hardware in order to relocate a dependency that is already behind a port.
///
/// ADR-040 permits exactly this shape: the contract sits in `core/`, one
/// feature satisfies it, another consumes it, and neither imports the other.
/// Amendment A-081 records the asymmetry so it reads as a decision rather than
/// an accident.
///
/// ## One `Connectivity` instance, two ports
///
/// §2 requires that the queue and the dispatcher *"neither polls it
/// independently, avoiding duplicated battery cost"*. There are two ports
/// above this plugin — `NetworkReader` for FR-CHK-04's one-shot checklist row,
/// and this one for §4's transition stream — but the composition root passes
/// **one** `Connectivity` instance to both, so there is a single plugin
/// channel underneath. That is the cost §2 is actually about.
class ConnectivityPlusConnectivitySource implements ConnectivitySource {
  /// Creates a source over [connectivity], or the plugin's own singleton.
  ///
  /// `main.dart` supplies the same instance it gives
  /// `ConnectivityPlusNetworkReader`. The default exists for tests and for a
  /// caller that has no instance to share.
  ConnectivityPlusConnectivitySource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<ConnectivityStatus> watch() async* {
    // Emitted before the first platform event, so a dispatcher subscribing
    // while already online starts immediately rather than waiting for a
    // transition that may never come. Chapter 5.12 §4's trigger is a
    // reconnection, but a listener's first question is "where am I now".
    ConnectivityStatus last = await current();
    yield last;

    await for (final List<ConnectivityResult> results
        in _connectivity.onConnectivityChanged) {
      final ConnectivityStatus next = _reduce(results);
      // Suppress duplicates. The platform reports interface reshuffles that
      // both reduce to `online` — a Wi-Fi to cellular hand-off, a VPN coming
      // up — and re-emitting those would have the dispatcher treat a steady
      // connection as a stream of reconnections.
      if (next == last) {
        continue;
      }
      last = next;
      yield next;
    }
  }

  @override
  Future<ConnectivityStatus> current() async {
    final List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } on Object catch (error, stackTrace) {
      throw DeviceException(
        errorCode: ErrorCode.deviceNetworkStatusUnreadable,
        message: 'The network status could not be read.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return _reduce(results);
  }

  /// Collapses the platform's interface list to Chapter 5.12 §2's two states.
  ///
  /// Deliberately simpler than `ConnectivityPlusNetworkReader._reduce`, which
  /// has to distinguish Wi-Fi from cellular because FR-CHK-04's sentence
  /// does. Nothing in Chapters 5.12 or 5.13 branches on the kind, so anything
  /// that is not `none` is online.
  static ConnectivityStatus _reduce(List<ConnectivityResult> results) {
    final bool anyUp = results.any(
      (ConnectivityResult r) => r != ConnectivityResult.none,
    );
    return anyUp ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }
}
