import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The Admin's write path over Projects, Tasks and assignments.
///
/// The other half of A-099's split, decided at Mission 5.1.1 and built here.
/// `ProjectTaskRepository` reads; this writes; **nothing holds both**. That is
/// what makes BR-18 and FR-ADM-07 — *"prevent a Collector from creating,
/// editing, or deleting Projects or Tasks, or from assigning Collectors"* — a
/// compile-time guarantee rather than a role check somebody has to remember in
/// every notifier.
///
/// Throws a `NetworkException` on every failure path, per error-handling.md
/// §26. Never returns null to signal failure.
///
/// ## Five methods, because Chapter 4.6 §3 has five write routes
///
/// | Method | Endpoint | Requirement |
/// |---|---|---|
/// | [createProject] | `POST /v1/projects` | FR-ADM-01 |
/// | [createTask] | `POST /v1/projects/{id}/tasks` | FR-ADM-02 |
/// | [updateTask] | `PATCH /v1/tasks/{id}` | FR-ADM-02 |
/// | [assignCollector] | `POST /v1/tasks/{id}/assignments` | FR-ADM-03 |
/// | [unassignCollector] | `DELETE /v1/tasks/{id}/assignments/{userId}` | FR-ADM-04 |
///
/// ## THREE CAPABILITIES ARE REQUIRED AND HAVE NO ROUTE
///
/// They are **deliberately absent**, on 5.1.1's `fetchTask(taskId)` precedent:
/// a port method Mission 7 has no endpoint to satisfy is a breaking rework
/// waiting to happen, and declaring one would hide the gap behind an interface
/// that looks complete.
///
/// - **Remove a Task.** FR-ADM-02 says *"create, edit, and **remove** Tasks"*
///   and MVP §2.2 repeats it. Chapter 4.6 §3 has no `DELETE /v1/tasks/{id}`.
///   Open item 85.
/// - **Edit a Project.** MVP §2.2 says *"Create, edit, and remove Projects"*
///   and Chapter 2.5's **A-04 is literally named "Create / Edit Project"**.
///   There is no `PATCH /v1/projects/{id}` — and no FR either: FR-ADM-01 is
///   create-only. Open item 86.
/// - **Remove or archive a Project.** No route, no FR, and the word *archive*
///   appears nowhere in Volume 1 or Volume 2 — yet `projects.archived_at` is a
///   live column that C-04 renders and A-104 reads. Open item 87.
///
/// ## Assignment is Task-level only — G3's resolution
///
/// FR-ADM-03 reads *"assign one or more Collectors to a **Project** and to
/// specific Tasks within it"*, and there is no `project_assignments` table and
/// no Project-scoped assignment route. **Every source that specifies a
/// mechanism is Task-only** — Chapter 4.4's tables, Chapter 4.6 §3's two
/// routes, US-29/30, and UC-07's own main flow (*"assigns them to the
/// Task"*). Only the summary-level statements say "Project".
///
/// Project-level assignment is therefore **derived, not stored**, exactly as
/// Chapter 4.6 §3's own row states: *"Collector: only Projects with an
/// assigned Task (BR-19)."* Assigning a Collector to any Task in a Project is
/// what makes that Project theirs, and BR-15's *"more than one Project
/// concurrently"* follows without a second table.
///
/// **What derivation cannot express** is a standing grant — *"assign this
/// Collector to every Task in this Project, including ones created later"*. A
/// Project-level assignment would be a rule; Task-level assignments are facts.
/// An Admin adding a Task next month must assign Collectors again and nothing
/// will remind them. That is a real product question, recorded as open item 84
/// rather than answered by an interface.
abstract interface class ProjectTaskAdminRepository {
  /// FR-ADM-01 — `POST /v1/projects`.
  ///
  /// Takes the two fields an Admin supplies. **`org_id`, `created_by`, `id`
  /// and `created_at` are all assigned server-side**: Chapter 4.8 derives org
  /// and actor from the verified token, and a client that sent either would be
  /// proposing its own scope on a rule BR-20 enforces at the API layer.
  ///
  /// Named parameters rather than a request object, matching
  /// `ChunkUploadApi.registerChunk`. A `NewProjectRequest` type would have one
  /// construction site and one consumer.
  ///
  /// Returns the created [Project] as the server rendered it, so a caller sees
  /// the assigned id without a second read.
  Future<Project> createProject({required String name, String? description});

  /// FR-ADM-02 — `POST /v1/projects/{id}/tasks`.
  ///
  /// [referenceExamples] defaults to empty rather than null, matching `Task`'s
  /// own collapse of Chapter 4.4 §3's nullable `jsonb` (A-097).
  ///
  /// **No `requirements` parameter**, because there is no such column and open
  /// item 69 is an unanswered product question. C-06 renders two of FR-PT-05's
  /// three things for the same reason (A-110); this is the write side of the
  /// same gap.
  Future<Task> createTask({
    required String projectId,
    required String title,
    required String instructions,
    List<String> referenceExamples,
  });

  /// FR-ADM-02's edit half — `PATCH /v1/tasks/{id}`.
  ///
  /// Every field is optional and null means *leave unchanged*, which is what
  /// `PATCH` means. Passing none is a no-op the caller should not make; Chapter
  /// 2.7's A-06 applies the same rule to its own confirm button, disabling it
  /// *"if no change was made from the loaded state, to avoid a no-op write and
  /// a false 'saved' confirmation"*.
  ///
  /// **[title] is included although Chapter 4.6 §3's purpose column says only
  /// *"Edit instructions/reference examples"*.** Chapter 4.4 §3 makes `title` a
  /// column of the row this route patches, and FR-ADM-02 says *"edit … Tasks"*
  /// without restriction — the purpose column reads as descriptive prose
  /// rather than an exhaustive field list. Recorded in the amendment as a
  /// judgement rather than a transcription, because it is the one signature
  /// here not fixed by a table.
  Future<Task> updateTask({
    required String taskId,
    String? title,
    String? instructions,
    List<String>? referenceExamples,
  });

  /// FR-ADM-03 — `POST /v1/tasks/{id}/assignments`.
  ///
  /// Task-scoped, per G3's resolution above. Idempotent by contract: assigning
  /// an already-assigned Collector is not an error, because Chapter 2.7's A-06
  /// saves a whole checkbox set at once and cannot know which boxes changed
  /// without a read endpoint that does not exist (open item 88).
  ///
  /// UC-07's exception flow requires that assigning a Collector who has no
  /// account or is deactivated is **blocked with an explanation** rather than
  /// silently accepted. That is the backend's judgement — this client has no
  /// user directory — so it arrives as a `NetworkException` carrying the
  /// envelope's error code.
  Future<void> assignCollector({
    required String taskId,
    required String collectorId,
  });

  /// FR-ADM-04 — `DELETE /v1/tasks/{id}/assignments/{userId}`.
  ///
  /// Idempotent for the same reason as [assignCollector]. Chapter 4.4 §4 makes
  /// this a soft removal — `removed_at`, *"kept for audit rather than
  /// hard-deleted"* — so a later re-assignment is a new row rather than a
  /// resurrection, and neither call needs to know which.
  ///
  /// **Reassignment is these two calls, not a third method.** UC-07's
  /// alternate flow — *"reassigns a Task from one Collector to another; the
  /// Task disappears from the first Collector's list and appears in the
  /// second's"* — is an unassign and an assign, and Chapter 4.6 §3's own row
  /// labels this endpoint *"remove/reassign"*. A `reassign` method would be
  /// two requests wearing one name, and a partial failure would leave the
  /// caller unable to tell which half landed.
  Future<void> unassignCollector({
    required String taskId,
    required String collectorId,
  });
}
