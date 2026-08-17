import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';

/// Reads GPS, battery and network at the moment a chunk is finalized.
///
/// Chapter 5.7 §2 is specific about the timing: these are read *"at the moment
/// of chunk finalization, not session start"*, because Chapter 5.7 §4 explains
/// they are *"only meaningful as of the actual capture moment"*.
///
/// ## Nothing implements this, and three dependencies stand behind it
///
/// GPS, battery percentage and network type have no source in `dart:io` or in
/// any package this project has admitted. Realistically that is `geolocator`,
/// `battery_plus` and `connectivity_plus` — three ADR-030 admissions — plus a
/// location permission that Volume 5.1 §3 assigns to the Pre-Recording
/// Checklist and that FR-CHK-01..05 does not currently include.
///
/// ## And a spec conflict this port cannot resolve
///
/// Reading GPS *at* finalization collides with NFR-META-01's 500 ms cap on
/// metadata generation: a cold fix routinely takes seconds. Amendment A-062
/// records it as a contradiction between two clauses rather than an
/// implementation problem, and it needs a product decision — await the fix,
/// use a cached one, or drop GPS from the hot path.
///
/// The return type makes absence explicit: an implementation that cannot read
/// a value returns null for it rather than omitting the group, so an
/// incomplete object is visibly incomplete.
abstract interface class CaptureConditionsReader {
  /// Reads whatever is available right now.
  ///
  /// Never throws for a missing permission or an unavailable sensor — that is
  /// a null field, not a failure. Throws a `DeviceException` only if a reading
  /// that should have worked did not.
  Future<MetadataCaptureConditions> read();
}
