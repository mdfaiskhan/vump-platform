/// The install-scoped device identifier Chapter 5.7 §2 requires — F19.
///
/// ## What it is, and what was rejected
///
/// A version-4 UUID, generated on first access and persisted. Volume 5 Chapter
/// 5.7 §2 asks for a *"cached, stable device identifier"* and does not say what
/// it should be; Mission 3 flagged that as undecided and it stayed undecided
/// until Mission 7.4.
///
/// **`ANDROID_ID` was rejected on two grounds.** It resets on factory reset, so
/// it is not stable across the one event it most needs to survive; and it is a
/// device-scoped identifier shared across the OS, which carries correlation
/// surface this project has no use for. An install-scoped random value tells
/// the backend exactly what it needs — *"these chunks came from the same
/// install"* — and nothing else.
///
/// The consequence, stated because it is the honest cost: **reinstalling the
/// app produces a new device id.** Nothing in Volume 4 or 5 depends on an id
/// surviving a reinstall — `chunk_metadata.device_id` is a correlator for
/// grouping and diagnosis, not a key — so this is the right trade rather than
/// a limitation being tolerated.
///
/// ## Why `shared_preferences` and not secure storage
///
/// ADR-008 scopes `flutter_secure_storage` to **secrets** — *"Secrets are
/// persisted through `flutter_secure_storage` and through nothing else"* — and
/// names JWT tokens and key material. A device id is not a secret: it travels
/// in plaintext metadata to a backend that stores it in an unencrypted column,
/// so putting it in the Keychain would misread the ADR's scope rather than add
/// safety.
///
/// `shared_preferences` is this project's established home for a small
/// persisted non-secret, with two precedents already: `OnboardingSeenStore` and
/// `WideAngleEligibilityCache`.
///
/// ## Why it is resolved at startup rather than read per chunk
///
/// `DeviceContext.deviceId` is a synchronous getter and this read is async.
/// Rather than make the contract async — which would ripple into
/// `ChunkMetadataAssembler` and every caller — the value is resolved once at
/// the composition root and injected, exactly as `appVersion` already is and
/// for the same reason.
library;

import 'package:mobile/core/identity/uuid_v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the persisted device id, generating and storing one on first call.
class DeviceIdStore {
  /// Creates a store over [preferences], minting with [uuid].
  DeviceIdStore({required SharedPreferences preferences, UuidV4? uuid})
    : this._(preferences, uuid ?? UuidV4());

  DeviceIdStore._(this._preferences, this._uuid);

  /// The key the value is persisted under.
  ///
  /// Namespaced like every other preference this project writes, so a reader of
  /// the store can tell what wrote it.
  static const String key = 'vump.device_id';

  final SharedPreferences _preferences;
  final UuidV4 _uuid;

  /// The device id for this install, generating one if none is stored.
  ///
  /// **Read before write, so generation happens exactly once.** A second call
  /// finds the stored value and returns it unchanged; that is the whole
  /// property, and it is what makes the id *stable* rather than merely
  /// *present*.
  ///
  /// A blank stored value is treated as absent. `MetadataIdentity.unsourced` is
  /// the empty string, so a row written before this existed — or by a defect
  /// that persisted the sentinel — must not be read back as a real id. That
  /// would be exactly the substitution A-068's Guard 1 exists to refuse.
  Future<String> deviceId() async {
    final String? stored = _preferences.getString(key);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final String minted = _uuid.next();
    await _preferences.setString(key, minted);
    return minted;
  }
}
