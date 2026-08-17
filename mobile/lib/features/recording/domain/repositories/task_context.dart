/// Supplies the Project and Task a session is recording against.
///
/// ## Why this is a port and not an import
///
/// Volume 4 Chapter 4.5's `identity` group needs `project_id` and `task_id`,
/// and both belong to `features/projects_tasks/` — whose `domain/`, `data/`
/// and `application/` are still `.gitkeep`. Even once they exist, ADR-022 R3
/// forbids a cross-feature import *"at any layer, in either direction"*.
///
/// So this follows the resolution the auth missions already established three
/// times: `core/` ↛ `features/` in Mission 2.3, `application/` ↛ `data/` in
/// Mission 2.4, and `settings/` ↛ `auth/` for sign-out. The consumer declares
/// what it needs; the composition root binds it.
///
/// Recorded in amendment A-062, along with the rest of the `identity` group's
/// missing sources.
abstract interface class TaskContext {
  /// The Project the active Task belongs to.
  String get projectId;

  /// The Task being recorded against.
  String get taskId;
}
