/// Reads the device's charge level for FR-CHK-03.
///
/// A port rather than a direct call because `battery_plus` is confined to
/// `features/recording/data/` — the same confinement `camera`, `crypto` and
/// `shared_preferences` already carry, and the reason `domain/` can be unit
/// tested without a platform.
abstract interface class BatteryReader {
  /// The current charge, 0–100.
  ///
  /// Throws a `DeviceException` if the platform cannot answer. The Checklist
  /// renders that as a failed row rather than swallowing it — a battery level
  /// that could not be read is not a battery level that passed.
  Future<int> percent();
}
