import 'package:mobile/features/recording/domain/entities/network_type.dart';

/// Reads the current connection kind for FR-CHK-04.
///
/// Returns a kind rather than a boolean because FR-CHK-04's obligation is to
/// *"inform the Collector whether upload will start immediately or be
/// queued"*, and that sentence differs by connection type.
abstract interface class NetworkReader {
  /// The current connection, or [NetworkType.none] when there is none.
  ///
  /// Absence of connectivity is a normal answer, not an error — Volume 2
  /// Chapter 2.9 §5 makes recording independent of the network. A platform
  /// that cannot answer at all throws a `DeviceException`.
  Future<NetworkType> current();
}
