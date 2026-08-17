/// One card of C-01's carousel — one permission, one reason.
///
/// Volume 1 FR-ONB-01 names five permissions: *"Camera, Microphone, Location
/// (When In Use), Notifications, and Files access"*. Volume 2 Chapter 2.5's
/// C-01 row names the same five, and Chapter 2.7's layout is *"one permission
/// per card"* with the primary button reading *"Next" on cards 1–4, "Get
/// Started" on the final card* — five cards.
///
/// ## Camera and Microphone are two cards, not one
///
/// Chapter 2.7's worked example combines them — *"Camera & Microphone — to
/// record your walkthroughs"* — which would make four cards and contradict
/// the same table's own button rule. Three of the four statements in the two
/// chapters say five; only the example says four. **Five was confirmed as a
/// product decision rather than inferred**, and the conflict is recorded as an
/// amendment so the example is not later read as authority.
///
/// ## The copy is one sentence, and states a concrete reason
///
/// Chapter 2.7: *"One sentence stating the permission and the concrete reason
/// it's needed."* Chapter 2.9 §2's named-cause rule is the same instinct — a
/// priming card that says *"we need Location for a better experience"* is the
/// generic message that chapter treats as a defect.
enum OnboardingPermission {
  /// FR-ONB-01's Camera. BR-03 pairs it with [microphone] as one recording
  /// gate, which is why FR-ONB-03 refuses to start without both.
  camera(
    title: 'Camera',
    reason: 'To record the walkthroughs your Tasks ask for.',
  ),

  /// FR-ONB-01's Microphone.
  microphone(
    title: 'Microphone',
    reason:
        'To capture audio alongside the video, as part of the same '
        'recording.',
  ),

  /// FR-ONB-01's Location (When In Use).
  ///
  /// "When In Use" is stated in the copy because it is the difference the
  /// Collector actually cares about, and the OS prompt will offer the choice.
  location(
    title: 'Location',
    reason:
        'To record where each chunk was captured, only while you are '
        'recording.',
  ),

  /// FR-ONB-01's Notifications.
  notifications(
    title: 'Notifications',
    reason: 'To tell you if an upload fails after you have left the app.',
  ),

  /// FR-ONB-01's Files access.
  files(
    title: 'Files',
    reason: 'To store recordings on this device until they finish uploading.',
  );

  const OnboardingPermission({required this.title, required this.reason});

  /// The permission's name, as the Collector sees it.
  final String title;

  /// One sentence, stating why this app asks for it.
  final String reason;

  /// The five cards, in the order FR-ONB-01 names them.
  static const List<OnboardingPermission> carousel = <OnboardingPermission>[
    camera,
    microphone,
    location,
    notifications,
    files,
  ];

  /// The primary button's label on this card.
  ///
  /// Chapter 2.7: *"'Next' on cards 1–4, 'Get Started' on the final card."*
  /// Derived from position rather than stored per case, so adding or removing
  /// a permission cannot leave two cards both reading "Get Started".
  String get primaryLabel => this == carousel.last ? 'Get Started' : 'Next';
}
