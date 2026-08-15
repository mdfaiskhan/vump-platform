import 'package:mobile/core/connectivity/connectivity_status.dart';

/// Volume 5 Chapter 5.12 §2's ConnectivityService.
///
/// The chapter describes one service that *"subscribes to the OS-level network
/// reachability API and exposes a simple online/offline signal to the rest of
/// the app — the Upload Queue (Chapter 5.9) and Background Upload dispatcher
/// (Chapter 5.11) both listen to it, but neither polls it independently,
/// avoiding duplicated battery cost."*
///
/// ## Declared in `core/`, implemented in `features/recording/data/`
///
/// ADR-040's pattern, applied a fifth time — and the most lopsided instance of
/// it so far, which is worth stating rather than glossing.
///
/// `connectivity_plus` is confined to `features/recording/data/` by the
/// `Architecture boundaries` job, because FR-CHK-04's Pre-Recording Checklist
/// was its first and only consumer. `features/upload/` is the second, and
/// ADR-022 R3 forbids it importing a sibling feature. So the contract sits on
/// neutral ground and the recording feature satisfies it.
///
/// **The asymmetry is real: `features/recording/` now supplies a signal it
/// does not itself consume through this contract.** Amendment A-081 records
/// why that was accepted rather than corrected. In short, the alternative —
/// moving the package to `core/connectivity/` as V3 Chapter 3.4's "Platform
/// Services" layer would suggest — means editing the checklist path that
/// Mission 3 verified on hardware, to relocate a dependency that is already
/// behind a port. The asymmetry is a naming discomfort; the edit is a risk to
/// working code.
///
/// ## Why this is not `NetworkReader` with a stream bolted on
///
/// `NetworkReader.current()` answers *"what kind of connection is there right
/// now"*, once, for a checklist row. This answers *"tell me when connectivity
/// comes back"*, continuously, for a dispatcher. Same plugin, different
/// questions, different lifetimes — and `NetworkReader` returns a
/// `features/recording/` type that `core/` may not name at all.
///
/// One `Connectivity` instance backs both, supplied at the composition root,
/// so §2's *"neither polls it independently"* holds at the plugin channel even
/// though there are two ports above it.
abstract interface class ConnectivitySource {
  /// Emits on every change to the online/offline signal.
  ///
  /// **Emits the current status immediately on subscription**, so a listener
  /// never has to combine this with [current] to know where it stands. That
  /// matters for Chapter 5.12 §4: a dispatcher that started while already
  /// online must not wait for the next transition to begin uploading.
  ///
  /// Duplicate consecutive values are suppressed. The platform reports
  /// interface changes that both reduce to `online` — Wi-Fi to cellular
  /// hand-off, a VPN connecting — and §4's trigger is the *transition*, not
  /// every reshuffle beneath it.
  Stream<ConnectivityStatus> watch();

  /// The current status, for a caller that does not want a subscription.
  ///
  /// Absence of connectivity is a normal answer rather than an error, as
  /// Chapter 5.12 §1 requires: recording has *"zero network dependency"*, so
  /// nothing about being offline is a fault. A platform that cannot answer at
  /// all throws a `DeviceException`.
  Future<ConnectivityStatus> current();
}
