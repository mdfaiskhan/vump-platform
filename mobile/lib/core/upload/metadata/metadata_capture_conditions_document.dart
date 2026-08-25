/// The `capture_conditions` group of Volume 4 Chapter 4.5 §2's wire shape.
///
/// **Uniformly absent for everything this application produces today.**
/// Amendment A-062 §3 records the unresolved conflict between Chapter 5.7 §2,
/// which wants a GPS fix at finalization, and NFR-META-01's 500 ms budget,
/// which a fix cannot be acquired inside. Battery and network *are* read on
/// device for the Checklist (FR-CHK-03/04) but are deliberately not written
/// into stored metadata pending the same decision.
///
/// So this group serialises as three nulls, and that is honest rather than
/// broken: the schema exists, the collection does not.
class MetadataCaptureConditionsDocument {
  /// Creates the capture-conditions group.
  const MetadataCaptureConditionsDocument({
    this.latitude,
    this.longitude,
    this.batteryPercent,
    this.networkType,
    this.thermalState,
  });

  /// `capture_conditions.gps.lat`.
  ///
  /// Volume 8 Chapter 8.6 §1 calls GPS *"the single most sensitive field this
  /// system collects"*. Nothing captures one today.
  final double? latitude;

  /// `capture_conditions.gps.lng`.
  final double? longitude;

  /// `capture_conditions.battery_pct`.
  final int? batteryPercent;

  /// `capture_conditions.network_type`, e.g. `wifi`.
  final String? networkType;

  /// Migration 0017. Android PowerManager thermal status, 0–6.
  final int? thermalState;

  /// Whether a fix was actually taken.
  ///
  /// A missing fix serialises as `{"lat": null, "lng": null}` and never as
  /// `{0.0, 0.0}` — which is a real place in the Gulf of Guinea, and the
  /// reason `MetadataCaptureConditions` rejected zeroes in the first place. A
  /// plausible wrong value is harder to catch than an obviously empty one.
  bool get hasFix => latitude != null && longitude != null;

  /// Chapter 4.5 §2's `capture_conditions` object.
  ///
  /// The chapter nests the coordinates under `gps` and names them `lat`/`lng`,
  /// not `latitude`/`longitude`. The `gps` object is always present, with null
  /// members when [hasFix] is false — omitting the key entirely would make
  /// "no fix" and "field not implemented" the same wire value.
  Map<String, Object?> toJson() => <String, Object?>{
    'gps': <String, Object?>{'lat': latitude, 'lng': longitude},
    'battery_pct': batteryPercent,
    'network_type': networkType,
    'thermal_state': thermalState,
  };
}
