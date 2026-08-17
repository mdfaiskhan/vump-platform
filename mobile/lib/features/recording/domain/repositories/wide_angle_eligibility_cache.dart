import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';

/// Remembers this device's wide-angle verdict between launches.
///
/// Volume 5.2 §2: the zoom-factor decision is *"a fixed per-device-model
/// decision made once at first launch and cached — not re-negotiated every
/// session — so footage from the same device is always comparable to itself
/// over time."*
///
/// ## The cache is correctness, not performance
///
/// Re-probing every session would not merely be slow. The probe opens the
/// camera, and a device that answered 0.5x once must answer 0.5x forever, or
/// footage from a single device stops being comparable to itself — which is
/// the property §2 asks for by name.
///
/// ## What is stored, and what is deliberately not
///
/// A tier name and two version strings. **No secret, no credential, no
/// identifier of any person or account.** That is what makes
/// `shared_preferences` the right store rather than `flutter_secure_storage`:
/// ADR-008 governs secrets, and this holds none. Writing non-secrets into
/// secure storage would blur the rule that makes ADR-008 checkable.
///
/// ## Staleness is decided by the fingerprint, not by a clock
///
/// [read] returns null when the stored fingerprint differs from the one
/// supplied, which is the re-probe trigger. There is no expiry: a verdict does
/// not become wrong with age, only with a change to the code that produced it
/// or the platform that answered it.
abstract interface class WideAngleEligibilityCache {
  /// The cached tier, or null if absent, unreadable, or from a different
  /// [fingerprint].
  ///
  /// Null is the only failure signal, deliberately — every reason to re-probe
  /// is the same instruction to the caller, and distinguishing "never stored"
  /// from "stored under an old app version" would give the caller a choice it
  /// has no different response to.
  Future<WideAngleTier?> read(DeviceFingerprint fingerprint);

  /// Stores [tier] against [fingerprint].
  ///
  /// Throws a `StorageException` if the write fails. A failed write is not
  /// fatal to recording — the verdict is still valid for this session and the
  /// next launch simply re-probes — but it is reported rather than swallowed,
  /// so a device that can never persist is visible rather than merely slow.
  Future<void> write({
    required WideAngleTier tier,
    required DeviceFingerprint fingerprint,
  });

  /// Forgets any stored verdict.
  ///
  /// Exists for the support path — a device that landed on the wrong tier
  /// through a platform bug needs a way back without a reinstall.
  Future<void> clear();
}
