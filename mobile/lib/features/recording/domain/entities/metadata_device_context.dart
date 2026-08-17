import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_device_context.freezed.dart';

/// The `device_context` group of Volume 4 Chapter 4.5's metadata schema.
///
/// Partially sourced. Chapter 5.7 §2 wants *"OS-reported device model/OS
/// version; app_version from the build"*:
///
/// - `os_version` — `Platform.operatingSystemVersion`, already used by
///   Mission 3.1's eligibility cache. No dependency.
/// - `app_version` — `AppInfo.fullVersion`, supplied through `DeviceContext`
///   rather than imported, because `app/config/` is granted to `core/` and
///   `shared/` by ADR-022 and not to a feature's `data/`.
/// - `device_model` — **no source.** Requires `device_info_plus` or a
///   platform channel; recorded in amendment A-062.
@freezed
class MetadataDeviceContext with _$MetadataDeviceContext {
  /// Creates the device-context group.
  const factory MetadataDeviceContext({
    /// From `DeviceContext` — no source in this project yet.
    required String deviceModel,

    /// From `Platform.operatingSystemVersion`.
    required String osVersion,

    /// From `AppInfo.fullVersion`, supplied rather than imported.
    required String appVersion,
  }) = _MetadataDeviceContext;
}
