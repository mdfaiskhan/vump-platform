import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/repositories/device_context.dart';

/// Supplies what the platform can answer, and [MetadataIdentity.unsourced] for
/// what it cannot.
///
/// **Two of four fields are real.** This is not a uniform stub, and the split
/// is worth reading:
///
/// | Field | Source | State |
/// |---|---|---|
/// | `appVersion` | the composition root, from `AppInfo` | **real** |
/// | `deviceModel` | needs `device_info_plus` or a channel | unsourced |
/// | `collectorId` | auth's `User.uid`, inverted (ADR-022 R3) | unsourced |
/// | `deviceId` | undecided — see below | unsourced |
///
/// `osVersion` is not here at all: `MetadataDeviceContext` takes it from
/// `Platform.operatingSystemVersion` directly, and this port never carried it.
///
/// `deviceId` is unsourced for a different reason from the other two. Chapter
/// 5.7 §2 asks for a *"cached, stable device identifier"* and **what it should
/// be is undecided** — install id, hardware id, or derived. That is a
/// decision, not a missing package.
///
/// ## `appVersion` is passed in, not imported
///
/// `app/config/` is granted to `core/` and `shared/` by ADR-022 and not to a
/// feature's `data/`. The composition root reads `AppInfo.fullVersion` and
/// hands it here, which is the same inversion Mission 3.6 recorded.
///
/// ## `collectorId` is the one that should worry a reader
///
/// A session recorded today cannot say who recorded it. `features/auth/`
/// *does* know — the gap is that reading it from here is the cross-feature
/// import ADR-022 R3 forbids *"at any layer, in either direction"*, and the
/// inversion that fixes it (a `DeviceContext` supplied at the composition root
/// from auth's own state) is a small mission rather than a missing dependency.
/// Recorded in A-064 as the cheapest of the five to close.
class PlatformDeviceContext implements DeviceContext {
  /// Creates a context reporting [appVersion] and the running platform.
  const PlatformDeviceContext({required this.appVersion});

  @override
  final String appVersion;

  @override
  String get deviceModel => MetadataIdentity.unsourced;

  @override
  String get collectorId => MetadataIdentity.unsourced;

  @override
  String get deviceId => MetadataIdentity.unsourced;
}
