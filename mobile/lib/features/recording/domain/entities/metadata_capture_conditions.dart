import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/features/recording/domain/entities/gps_fix.dart';

part 'metadata_capture_conditions.freezed.dart';

/// The `capture_conditions` group of Volume 4 Chapter 4.5's metadata schema.
///
/// Chapter 5.7 §2: *"GPS (if permission granted), battery %, network type —
/// read at the moment of chunk finalization, not session start"*.
///
/// ## Nothing here has a source yet, and that is visible rather than hidden
///
/// All three fields are nullable, and a metadata object assembled today
/// carries [unavailable] — every value null. That is a deliberate choice over
/// the two alternatives:
///
/// - **Omitting the group** would make an incomplete object structurally
///   indistinguishable from a complete one at the wire level, so a backend
///   receiving it could not tell "this device had no GPS permission" from
///   "this build never implemented GPS".
/// - **Defaulting to zeroes** would be worse still: `{"lat": 0.0, "lng": 0.0}`
///   is a real place in the Gulf of Guinea, and a plausible-looking wrong
///   value is harder to catch than an obvious empty one.
///
/// [isComplete] exists so a caller can ask directly.
///
/// ## GPS is also the subject of an unresolved spec conflict
///
/// §2 requires the reading *at* finalization, and NFR-META-01 caps metadata
/// generation at 500 ms. A cold GPS fix routinely takes several seconds.
/// Amendment A-062 records that as a contradiction between two clauses
/// needing a product decision — whether the fix is awaited, taken from a
/// cache, or dropped from the hot path — and it is **not** resolved here.
@freezed
class MetadataCaptureConditions with _$MetadataCaptureConditions {
  /// Creates the capture-conditions group.
  const factory MetadataCaptureConditions({
    /// Null when location permission was refused, or — today — when nothing
    /// reads it at all.
    GpsFix? gps,

    /// Battery charge percentage, 0-100. Null when unavailable.
    int? batteryPercent,

    /// `"wifi"`, `"cellular"`, `"none"`. Null when unavailable.
    String? networkType,
  }) = _MetadataCaptureConditions;

  const MetadataCaptureConditions._();

  /// Every condition absent — what this project can currently produce.
  ///
  /// Named so that a metadata object built today says *"these were not
  /// read"* explicitly at its call site, rather than through three separate
  /// omitted arguments.
  static const MetadataCaptureConditions unavailable =
      MetadataCaptureConditions();

  /// Whether every condition Chapter 4.5 lists was actually captured.
  ///
  /// False for anything this project produces today. A consumer that requires
  /// complete conditions can check rather than infer.
  bool get isComplete =>
      gps != null && batteryPercent != null && networkType != null;

  /// Whether nothing at all was captured.
  bool get isEmpty =>
      gps == null && batteryPercent == null && networkType == null;
}
