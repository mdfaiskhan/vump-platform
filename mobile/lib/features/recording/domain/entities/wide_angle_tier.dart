/// Which rung of Volume 5.1 §2's capability ladder a device landed on.
///
/// Three values because the chapter's table has three rows, named for the
/// approach rather than the number so that a stored value stays readable when
/// the ladder is read years later.
///
/// This is the coarse, persistable form of the verdict — it is what the
/// eligibility cache writes. The full result, including the zoom factor and
/// the reason for a block, is `WideAngleEligibility`.
enum WideAngleTier {
  /// Tier 1 — a dedicated ultra-wide physical lens was found and selected.
  ///
  /// *"True optical wide-angle — preferred, matches BR-02 exactly."*
  opticalDedicated('OPTICAL_DEDICATED'),

  /// Tier 2 — the primary rear sensor zooms out to 0.5x/0.6x itself.
  ///
  /// *"Optical or hybrid wide-angle at the correct factor."* The chapter is
  /// deliberately imprecise about which, because the device does not say.
  primarySensorZoom('PRIMARY_SENSOR_ZOOM'),

  /// Tier 3 — neither is available and recording is blocked.
  ///
  /// *"Consistent, honest failure — never a silent BR-02 violation."*
  unsupported('UNSUPPORTED');

  const WideAngleTier(this.storageKey);

  /// The stable string written to the eligibility cache.
  ///
  /// Separate from [name] on purpose: renaming an enum constant is a
  /// refactor, and it must not silently invalidate every cached verdict in
  /// the field.
  final String storageKey;

  /// Reads a [storageKey] back, or null if it names no known tier.
  ///
  /// Null rather than a throw or a default: an unrecognised key means the
  /// cache was written by a different version of this enum, and the honest
  /// response is to re-probe rather than to guess a tier.
  static WideAngleTier? fromStorageKey(String? key) {
    for (final WideAngleTier tier in WideAngleTier.values) {
      if (tier.storageKey == key) {
        return tier;
      }
    }
    return null;
  }
}
