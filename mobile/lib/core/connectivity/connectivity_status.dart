/// Volume 5 Chapter 5.12 §2's *"simple online/offline signal"*.
///
/// Two states, and deliberately not three. `connectivity_plus` reports an
/// interface list, and `features/recording/`'s `NetworkType` reduces that to
/// wifi/cellular/none because FR-CHK-04's checklist sentence differs by
/// connection kind — *"whether upload will start immediately or be queued"*.
///
/// Chapter 5.12 asks a narrower question. §4's trigger is an **online
/// transition**, and an upload that starts on cellular is the same upload that
/// starts on Wi-Fi: nothing in Chapters 5.12 or 5.13 branches on the kind.
/// Carrying the kind here would publish a distinction no consumer of this
/// contract uses, which is the coupling ADR-040's projection rule exists to
/// prevent.
///
/// ## This is a radio status, not reachability
///
/// The plugin's own documentation warns that its result *"only gives you the
/// radio status"* and must not be taken as proof a request will succeed.
/// Chapter 5.12 §4 puts exactly that weight on it — an online transition is a
/// reason to *try*, not a promise of success. When the attempt fails anyway,
/// Chapter 5.13's backoff is what handles it.
enum ConnectivityStatus {
  /// At least one interface is up.
  online,

  /// No interface is up.
  offline;

  /// Whether an upload should be attempted.
  bool get isOnline => this == ConnectivityStatus.online;
}
