import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_identity.freezed.dart';

/// The `identity` group of Volume 4 Chapter 4.5's metadata schema.
///
/// Four of its five fields have no source in this application yet, and they
/// are **required rather than nullable** on purpose: a chunk that cannot say
/// which Task it belongs to or who recorded it is not a valid record, and
/// making them optional would let one be assembled anyway.
///
/// `project_id`, `task_id` and `collector_id` arrive through ports —
/// `TaskContext` and `DeviceContext` — because `features/projects_tasks/` is
/// unbuilt and `collector_id` is `features/auth/`'s `User.uid`, which
/// ADR-022 R3 forbids importing across features "at any layer, in either
/// direction". Amendment A-062 records the gap.
@freezed
class MetadataIdentity with _$MetadataIdentity {
  /// Creates the identity group.
  const factory MetadataIdentity({
    /// From `RecordingSession.sessionId` (Mission 3.2).
    required String sessionId,

    /// From `TaskContext` — no source in this feature.
    required String projectId,

    /// From `TaskContext` — no source in this feature.
    required String taskId,

    /// From `DeviceContext` — `features/auth/`'s `User.uid`, inverted.
    required String collectorId,

    /// From `DeviceContext` — a "cached, stable device identifier"
    /// (Ch. 5.7 §2). Nothing in the project produces one yet.
    required String deviceId,
  }) = _MetadataIdentity;

  const MetadataIdentity._();

  /// The value a field carries when nothing in this application can supply it.
  ///
  /// **The empty string, chosen because it cannot be mistaken for an id.**
  /// Mission 3.8 had to put *something* in these fields to record footage at
  /// all — the alternative was failing every chunk, which would have lost real
  /// recordings to a bookkeeping gap and broken the Constitution's "never lose
  /// a take". This is the value that carries the least claim.
  ///
  /// It follows `MetadataCaptureConditions`' reasoning about `{0.0, 0.0}`: a
  /// plausible-looking wrong value is harder to catch than an obviously empty
  /// one. `'unassigned'`, `'unknown'` or a generated placeholder would all read
  /// as data. This reads as absence, sorts as absence, and fails
  /// [isComplete].
  ///
  /// A-062 owns closing the gap; A-064 records this stand-in.
  static const String unsourced = '';

  /// Whether every field names something real.
  ///
  /// **False for anything this project produces today.** Exposed so a consumer
  /// — the Upload Queue above all, which must not send a chunk claiming an
  /// empty `collector_id` — can ask rather than inspect five fields.
  bool get isComplete =>
      sessionId != unsourced &&
      projectId != unsourced &&
      taskId != unsourced &&
      collectorId != unsourced &&
      deviceId != unsourced;
}
