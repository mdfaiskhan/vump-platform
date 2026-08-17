import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/repositories/network_reader.dart';

/// Reads FR-CHK-04's connection kind through `connectivity_plus`.
///
/// ## The plugin returns a list, and the domain needs one answer
///
/// `checkConnectivity()` returns every active interface — a phone on Wi-Fi
/// with mobile data up reports both, and a satellite link appears alongside
/// `mobile`. [_reduce] collapses that to the single kind FR-CHK-04's sentence
/// depends on, preferring the interface an upload would actually take.
///
/// **Wi-Fi wins over cellular, and any connection wins over none.** FR-CHK-04
/// asks whether upload *"will start immediately or be queued"*, and the answer
/// is yes if any interface can carry it. Reporting `cellular` for a device
/// that also has Wi-Fi would be true and useless.
///
/// ## What this deliberately does not claim
///
/// The plugin's own documentation warns that the result *"only gives you the
/// radio status"* and must not be used to decide whether a request will
/// succeed. That is exactly the weight FR-CHK-04 puts on it: the row informs,
/// and Chapter 2.9 §5 forbids it from blocking recording. Nothing in this
/// project treats it as reachability.
class ConnectivityPlusNetworkReader implements NetworkReader {
  /// Creates a reader over [connectivity], or the plugin's own singleton.
  ConnectivityPlusNetworkReader({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkType> current() async {
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

  /// Collapses the platform's interface list to one kind.
  ///
  /// `ethernet` and `vpn` map to [NetworkType.wifi] rather than gaining
  /// values of their own: Volume 4 Chapter 4.5 fixes the stored vocabulary at
  /// three spellings, and both are unmetered connections an upload starts on
  /// immediately, which is the only distinction FR-CHK-04 draws.
  static NetworkType _reduce(List<ConnectivityResult> results) {
    if (results.any(
      (ConnectivityResult r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    )) {
      return NetworkType.wifi;
    }
    if (results.any(
      (ConnectivityResult r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.other ||
          r == ConnectivityResult.bluetooth,
    )) {
      return NetworkType.cellular;
    }
    return NetworkType.none;
  }
}
