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
///
/// ## Why it lives in `core/` — Mission 7.4
///
/// It was declared in `features/recording/domain/repositories/`, which worked
/// only while `features/recording/` was the sole consumer. The moment
/// `features/projects_tasks/` supplies the values, a contract owned by another
/// feature is precisely the *"either direction"* R3 forbids — the implementor
/// would have to import the sibling that declares it.
///
/// `folder-structure.md`'s R3 gives four resolutions in order of preference
/// and this is the first: **the concept is infrastructure, so it moves to
/// `core/`.** ADR-022 anticipated this exact pair by name, four missions in
/// advance — *"`recording` and `upload` will make a cross-feature import look
/// locally sensible, since one produces chunks and the other consumes them"* —
/// and deliberately did not choose, *"because the right choice depends on what
/// the chunk turns out to be."*
///
/// **The implementations stay in `features/recording/data/`.** R5's split rule
/// asks whether the thing performs I/O; the contract does not and the
/// implementations do.
abstract interface class TaskContext {
  /// The Project the active Task belongs to.
  String get projectId;

  /// The Task being recorded against.
  String get taskId;
}
