/// The Task a Collector is about to record against — Mission 7.4, F38.
///
/// ## Why this exists, and why it is so small
///
/// `features/projects_tasks/` knows which Task was chosen;
/// `features/recording/` needs to stamp it onto the session it creates.
/// ADR-022 R3 forbids either importing the other *"at any layer, in either
/// direction"*, so the fact travels through `core/` — R3's first resolution,
/// the same one `TaskContext` and `DeviceContext` already take.
///
/// It carries the two ids Volume 4 Chapter 4.5 §2's `identity` group needs and
/// nothing else. Not a `Task`: a Task's title, instructions and reference
/// examples belong to the feature that renders them, and putting the whole
/// entity in `core/` would make `core/` the owner of a domain type two features
/// then have to agree on. Two strings is the whole crossing.
///
/// ## Its lifetime is one navigation, not the recording
///
/// C-06 sets it when the Collector taps *Start Recording*; `checklistPassed`
/// reads it and writes both ids onto the `LocalSession` row. After that **the
/// Isar row is the source of truth** — the upload path reads `taskId` from it
/// at claim time, hours or days and any number of relaunches later.
///
/// So this is deliberately **not** persisted, and that is not a gap:
///
/// - A process death mid-recording loses the recording itself. There is no
///   resume path — no launch-time recovery reads an `in_progress` session, and
///   `IsarChunkStore` records that `status` *"stays `in_progress` forever"*.
///   Persisting the selection would restore Task context into a recording that
///   no longer exists.
/// - Everything that outlives the process — finalized chunks' metadata, and the
///   upload queue's `taskId` — is already on disk by then.
///
/// Adding a second persisted store for a value the session row already holds
/// would be a parallel mechanism, which F38 explicitly refused.
library;

/// The Project and Task a session will record against.
class SelectedTask {
  /// Creates a selection.
  const SelectedTask({required this.projectId, required this.taskId});

  /// The owning Project — Chapter 4.5 §2's `project_id`.
  ///
  /// Carried alongside the Task rather than derived from it, because the only
  /// route that could derive it is `GET /v1/projects/{id}/tasks`, and C-06
  /// already holds the `Task` that names it. Deriving it would be a network
  /// call to learn something the caller just had in hand.
  final String projectId;

  /// The Task — Chapter 4.5 §2's `task_id`.
  final String taskId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedTask &&
          other.projectId == projectId &&
          other.taskId == taskId;

  @override
  int get hashCode => Object.hash(projectId, taskId);

  @override
  String toString() => 'SelectedTask($projectId/$taskId)';
}
