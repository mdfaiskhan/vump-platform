/// The rows of Volume 2 Chapter 2.7's C-07, in the order they are shown.
///
/// Five, not four: amendment A-057 added [wideAngleCapability] as a sixth
/// FR-CHK item, and FR-CHK-05 is not a row — it is the rule that blocks when
/// any of these fails.
///
/// ## The order is the sequencing, not a layout preference
///
/// [cameraAndMicrophone] is first because Volume 5 Chapter 5.1 §3 puts
/// permission before the capability probe, and the probe opens the camera —
/// which cannot succeed without the grant. [wideAngleCapability] is therefore
/// last, and the notifier runs the rows in this order rather than in parallel.
enum ChecklistCheck {
  /// FR-CHK-01 — both grants BR-03 requires, verified by opening the camera
  /// with audio enabled.
  cameraAndMicrophone,

  /// FR-CHK-02 — free space for at least one full chunk.
  freeStorage,

  /// FR-CHK-03 — battery at or above the configured minimum.
  batteryLevel,

  /// FR-CHK-04 — connectivity. Reported, never blocking (Ch. 2.9 §5).
  network,

  /// A-057's sixth item — the wide-angle verdict, cached per device.
  wideAngleCapability,
}
