/// The `device_context` group of Volume 4 Chapter 4.5 §2's wire shape.
class MetadataDeviceContextDocument {
  /// Creates the device-context group.
  const MetadataDeviceContextDocument({
    this.deviceModel,
    this.osVersion,
    this.appVersion,
  });

  /// `device_context.device_model`.
  final String? deviceModel;

  /// `device_context.os_version`.
  final String? osVersion;

  /// `device_context.app_version`.
  final String? appVersion;

  /// Chapter 4.5 §2's `device_context` object.
  Map<String, Object?> toJson() => <String, Object?>{
    'device_model': deviceModel,
    'os_version': osVersion,
    'app_version': appVersion,
  };
}
