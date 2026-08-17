/// Verifies FR-CHK-01's two grants, by using them.
///
/// ## Why this is a probe and not a permission query
///
/// This project has no permission plugin, and adding one would be an ADR-030
/// admission for a question the camera can already answer: opening a camera
/// **with audio enabled** succeeds only when both grants are held, and fails
/// with a plugin code naming which one is missing. That is a stronger check
/// than a status query anyway — it verifies the capability rather than the
/// bookkeeping.
///
/// ## It also triggers the OS prompt, which is what C-01 primes
///
/// The first call surfaces the platform's native dialog. Volume 2 Chapter 2.9
/// §6 requires exactly that: the onboarding carousel *"primes the Collector
/// beforehand but never replaces or restyles the OS-native dialog itself"*.
///
/// ## Live, every session — deliberately not cached
///
/// Amendment A-057 draws the line: a grant *"can be revoked in Settings"*, so
/// it must be read at the moment recording starts. Only the wide-angle verdict
/// is cached, because it is a property of the hardware.
abstract interface class CameraPermissionProbe {
  /// Opens and immediately releases a camera with audio, to confirm both
  /// grants.
  ///
  /// Returns normally when both are held. Throws a `DeviceException` carrying
  /// `devicePermissionCameraDenied` or `devicePermissionMicrophoneDenied` —
  /// which is what lets C-08 name the specific failed check rather than
  /// reporting a generic camera error.
  Future<void> verify();
}
