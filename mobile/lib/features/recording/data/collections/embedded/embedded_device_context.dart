import 'package:isar/isar.dart';

part 'embedded_device_context.g.dart';

/// The `device_context` group on disk.
@embedded
class EmbeddedDeviceContext {
  /// Creates a stored EmbeddedDeviceContext.
  EmbeddedDeviceContext();

  /// OS-reported model. From `DeviceContext`; no source yet.
  String? deviceModel;

  /// From `Platform.operatingSystemVersion`.
  String? osVersion;

  /// From `AppInfo.fullVersion`, supplied rather than imported.
  String? appVersion;
}
