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
}
