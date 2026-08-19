import 'package:mobile/core/identity/interfaces/device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';

/// Supplies Chapter 4.5 §2's device and Collector identifiers.
///
/// ## All four values are resolved by the composition root, not read here
///
/// | Field | Source | Why not here |
/// |---|---|---|
/// | `collectorId` | `features/auth/`'s `User.uid` | ADR-022 R3 — inverted |
/// | `deviceId` | `core/identity/DeviceIdStore` | async read, sync getter |
/// | `deviceModel` | `core/identity/DeviceModelChannel` | async read, sync getter |
/// | `appVersion` | `AppInfo.fullVersion` | ADR-022 — `app/config/` is
///   not granted to a feature's `data/` |
///
/// The first is a boundary rule. The middle two are the sync/async seam: the
/// contract's getters are synchronous and both reads are futures, so rather
/// than make `DeviceContext` async — which would ripple into
/// `ChunkMetadataAssembler` and every caller of it — the values are resolved
/// once at startup and injected, exactly as `appVersion` already was and for
/// the same reason. Mission 7.4, F19 and F22.
///
/// ## Nothing defaults
///
/// Every field is required. `MetadataIdentity.unsourced` is still reachable —
/// the composition root passes it when a value genuinely is not available, and
/// `PlatformDeviceContext.unsourced` names that case — but it arrives as a
/// deliberate argument rather than as a fallback this class chose. A-068's
/// Guard 1 then refuses the chunk, which is the behaviour that must survive: an
/// unattributed recording is refused, never uploaded with a plausible blank.
class PlatformDeviceContext implements DeviceContext {
  /// Creates a context over values the composition root has already resolved.
  const PlatformDeviceContext({
    required this.collectorId,
    required this.deviceId,
    required this.deviceModel,
    required this.appVersion,
  });

  /// A context whose every identifier is absent.
  ///
  /// For a state where nothing is resolvable — no signed-in Collector, no
  /// persisted device id. It is spelled out rather than defaulted so that a
  /// reader of a call site can see that the blanks were chosen.
  const PlatformDeviceContext.unsourced({required this.appVersion})
    : collectorId = MetadataIdentity.unsourced,
      deviceId = MetadataIdentity.unsourced,
      deviceModel = MetadataIdentity.unsourced;

  @override
  final String collectorId;

  @override
  final String deviceId;

  @override
  final String deviceModel;

  @override
  final String appVersion;
}
