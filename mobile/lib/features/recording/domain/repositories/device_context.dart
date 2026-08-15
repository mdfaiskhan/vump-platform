/// Supplies the device and Collector identifiers metadata needs.
///
/// Three values, none of which this feature can obtain on its own:
///
/// - [collectorId] is `features/auth/`'s `User.uid`. Reading it directly is
///   the cross-feature import ADR-022 R3 forbids, so it is inverted for the
///   same reason as `TaskContext`.
/// - [deviceModel] has no source at all. It needs `device_info_plus` or a
///   platform channel, and neither has been admitted under ADR-030.
/// - [deviceId] is Chapter 5.7 §2's *"cached, stable device identifier"*.
///   Nothing in this project produces or caches one, and what it should be —
///   an install id, a hardware id, something derived — is undecided.
///
/// [appVersion] is here for a different reason: `AppInfo.fullVersion` exists,
/// but ADR-022 grants `app/config/` reads to `core/` and `shared/` and not to
/// a feature's `data/`. Supplying it through the same port keeps that rule
/// intact without arguing about it.
///
/// All four are recorded in amendment A-062.
abstract interface class DeviceContext {
  /// The signed-in Collector's id — `features/auth/`'s `User.uid`.
  String get collectorId;

  /// A cached, stable device identifier (Ch. 5.7 §2).
  String get deviceId;

  /// The OS-reported device model.
  String get deviceModel;

  /// The build's version, as `AppInfo.fullVersion` reports it.
  String get appVersion;
}
