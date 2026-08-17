import 'package:mobile/features/recording/domain/entities/recording_state.dart';

/// BR-04's gate, as a redirect rule.
///
/// > *Recording shall not be permitted unless the Pre-Recording Checklist
/// > passes (permissions, storage, battery, network).* — Volume 1, BR-04
///
/// Volume 2 Chapter 2.3 §5 makes the Checklist *"the only route toward
/// capture"*, and until Mission 3.8 nothing enforced that: `/recording/:id`
/// was reachable by typing it. The route table itself records this as a known
/// gap, and this closes it.
///
/// ## A disabled button is not the gate
///
/// The Checklist screen disables Start Recording until every row passes, which
/// stops a tap. It does not stop a deep link, a restored route on relaunch, or
/// a `context.go` from code written later. BR-04 is a rule about what the
/// system permits, so it is enforced where navigation is decided.
///
/// ## The condition is the lifecycle, not the checklist's own result
///
/// The check is *"is there a live session"*, not *"did the checklist pass"*.
/// They are the same fact by construction — `RecordingLifecycle` leaves `Idle`
/// only through `onChecklistPassed`, which is the only edge into `Ready`, and
/// `Ready` is the only edge into `Recording`. Reading the state machine rather
/// than re-reading the checklist means the guard cannot disagree with the
/// thing it is guarding.
///
/// This mirrors `AuthGuard`: a pure function of state and location, with no
/// `Ref`, no navigation and no side effects, so the whole rule is testable
/// without a widget tree (ADR-037).
abstract final class RecordingGuard {
  /// The route prefix for the chrome-free capture surface.
  static const String recordingPrefix = '/recording/';

  /// The route prefix for C-10.
  static const String processingPrefix = '/processing/';

  /// Where a Collector with no session belongs — the Record tab, which
  /// Chapter 2.4 §2 defines as a shortcut into a Task's checklist.
  static const String fallbackRoute = '/collector/record';

  /// Null to allow, or the route to send this person to instead.
  ///
  /// [state] is the recording lifecycle's current state.
  static String? redirect({
    required RecordingState state,
    required String location,
  }) {
    if (location.startsWith(recordingPrefix)) {
      // `Ready` counts: the session exists and the camera is open, which is
      // the state the Checklist hands over in. `Finalizing` does not — capture
      // has ended and C-10 owns the screen from there.
      final bool live =
          state is RecordingStateReady || state is RecordingStateRecording;
      if (!live) {
        return fallbackRoute;
      }
      return _sessionMatches(state, location) ? null : fallbackRoute;
    }

    if (location.startsWith(processingPrefix)) {
      // Reachable while draining, and for the moment after — `Idle` carries
      // `lastCompletedSession`, which is what the screen's final state reads.
      // A cold start has neither, so there is nothing to show.
      if (state is RecordingStateIdle && state.lastCompletedSession == null) {
        return fallbackRoute;
      }
      return null;
    }

    return null;
  }

  /// Whether the session named in the path is the session actually running.
  ///
  /// A stale link — an old session id from history or a restored route —
  /// would otherwise show the live recording under someone else's identifier,
  /// and the screen's Stop would end a session the URL does not name.
  static bool _sessionMatches(RecordingState state, String location) {
    final String? active = state.activeSession?.sessionId;
    if (active == null) {
      return false;
    }
    return location.substring(recordingPrefix.length) == active;
  }
}
