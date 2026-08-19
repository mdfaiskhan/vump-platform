import 'package:freezed_annotation/freezed_annotation.dart';

part 'recording_session.freezed.dart';

/// One recording session, and the parameters fixed for its whole duration.
///
/// Volume 5 Chapter 5.6 §2: *"`session_id` is generated once, at session
/// start, and stamped on every chunk in that session — chunking never creates
/// a new `session_id`."* Chapter 5.14 §3 adds that it is a UUID and assigns
/// its generation to Chapter 5.3, which is this mission.
///
/// ## Why the zoom factor lives here
///
/// Chapter 5.2 §1 fixes it: the factor is *"selected once at session start via
/// Chapter 5.1's capability ladder; fixed for the whole session, never changed
/// mid-recording."* Holding it on the session rather than re-reading it per
/// chunk is what makes that guarantee structural — there is one value, decided
/// before `Recording` is entered, and every chunk in the session reads the
/// same one.
///
/// **It is a `double`, not a `WideAngleEligibility`.** The lifecycle does not
/// re-decide eligibility and cannot: Chapter 5.1 §3 assigns that to the
/// Pre-Recording Checklist, and taking the verdict here would make the
/// ineligible case representable at a layer that has no business acting on it.
/// The Checklist resolves the verdict to a factor; this carries the factor.
@freezed
class RecordingSession with _$RecordingSession {
  /// Creates a session.
  const factory RecordingSession({
    /// The UUID generated once at session start (Chapter 5.14 §3).
    required String sessionId,

    /// The Task this session records against, and its Project.
    ///
    /// Nullable because a session can be started without a selection —
    /// `PlatformTaskContext` then reports both as `MetadataIdentity.unsourced`
    /// and A-068's Guard 1 refuses the chunk at upload. Carried on the session
    /// rather than read ambiently at finalization so that every chunk of one
    /// recording is attributed to the same Task, even if the selection changes
    /// underneath. Mission 7.4, F38.
    String? taskId,
    String? projectId,

    /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
    required double zoomFactor,

    /// When the Collector tapped Start.
    required DateTime startedAt,
  }) = _RecordingSession;
}
