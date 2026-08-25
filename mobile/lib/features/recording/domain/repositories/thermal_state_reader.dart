/// Reads the device's thermal status at a moment in time.
///
/// Volume 5 Chapter 5.7 §2 wants capture conditions read *"at the moment of
/// chunk finalization, not session start"*, so this is called once per chunk
/// rather than watched.
///
/// ## Null is a value this port is expected to return
///
/// Migration 0017's column is nullable, and the reason is not defensiveness:
/// `PowerManager.getCurrentThermalStatus()` is API 29+, and a device below
/// that genuinely cannot answer. **An implementation must return null rather
/// than throw** — a failed thermal read must never fail a chunk finalization,
/// because the footage is fine and only one field is missing.
///
/// **Zero is a reading, not absence.** `THERMAL_STATUS_NONE` is 0 and means the
/// device is cool. A caller that treats `0` and `null` alike erases the
/// difference between a device that reported it was fine and one that reported
/// nothing, which is the distinction the nullable column exists to keep.
abstract interface class ThermalStateReader {
  /// The current thermal status, 0–6, or null where unavailable.
  ///
  /// The scale is Android's `PowerManager`: 0 `NONE`, 1 `LIGHT`, 2 `MODERATE`,
  /// 3 `SEVERE`, 4 `CRITICAL`, 5 `EMERGENCY`, 6 `SHUTDOWN`.
  Future<int?> currentThermalState();
}
