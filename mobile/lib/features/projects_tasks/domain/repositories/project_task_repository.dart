import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// The Collector's read path over Projects and Tasks — FR-PT-03, FR-PT-04 and
/// FR-PT-05.
///
/// Volume 3 Chapter 3.4 §2 names this repository `ProjectTaskRepository`; the
/// name is transcribed rather than chosen.
///
/// Throws a `NetworkException` on every failure path, per error-handling.md
/// §26: `data/` throws `AppException` subclasses, and the
/// exception-to-`Failure` conversion happens exactly once, in `application/`.
/// Never returns null instead of throwing, and never returns an empty list to
/// mean a failure — an empty list means the Collector has no assigned work,
/// which is a real and different answer.
///
/// ## This interface is READ-ONLY, and the split is the decision
///
/// Every write in FR-ADM — create a Project (FR-ADM-01), create/edit/remove a
/// Task (FR-ADM-02), assign and unassign a Collector (FR-ADM-03/04) — belongs
/// to a **separate** `ProjectTaskAdminRepository`, declared and built by
/// Mission 5.2 rather than added as more methods here.
///
/// The split is not tidiness. **It makes BR-18 and FR-ADM-07 a compile-time
/// guarantee instead of a runtime check.** FR-ADM-07 requires the system to
/// *"prevent a Collector from creating, editing, or deleting Projects or
/// Tasks, or from assigning Collectors"*. A Collector-side notifier that only
/// ever reads this provider **cannot call a write path**, because the methods
/// are not on the type it holds. One interface with nine methods would make
/// that a role check somebody has to remember to write, in every notifier,
/// forever.
///
/// It is decided now rather than in 5.2 because retrofitting the split after
/// five write methods have call sites means moving those call sites; declaring
/// it now costs a sentence.
///
/// ## Why there is no `fetchTask(String taskId)`
///
/// **Volume 4 Chapter 4.6 §3 has no `GET /v1/tasks/{id}`.** The catalog offers
/// exactly three Task routes — `GET /v1/projects/{id}/tasks`,
/// `POST /v1/projects/{id}/tasks` and `PATCH /v1/tasks/{id}` — so a single
/// Task is reachable only through its Project's list.
///
/// Declaring a by-id fetch here would put a method on the port that Mission 7
/// has no endpoint to implement, which is the breaking rework this interface
/// was traced against Chapter 4.6 specifically to avoid. C-06's Task Detail is
/// therefore served by selecting from [fetchTasks]'s result.
///
/// That leaves one gap, named here rather than discovered later: C-06's route
/// carries only a `taskId`, so a **deep link or a cold start straight into
/// Task Detail has no Project to list from**. Resolving it needs either a
/// backend route that does not exist or a local cache that is not built
/// (`local_task_cache`, ADR-039 §3). It is logged as an open item and owed to
/// Mission 5.1.2, which is where a route first has to resolve.
abstract interface class ProjectTaskRepository {
  /// The Projects this Collector may see — `GET /v1/projects`.
  ///
  /// **Takes no collector id, deliberately.** Volume 4 Chapter 4.8 states that
  /// *"every endpoint in Chapter 4.6 re-derives role and scope from the
  /// verified token context"*, and Chapter 4.2 §3 has the API layer always
  /// inject `WHERE task_assignments.user_id = :current_user`, *"never left
  /// optional"*. So BR-19's *"a Collector shall never have visibility into a
  /// Project or Task they are not assigned to"* is enforced server-side from
  /// the bearer token, and Chapter 4.6 §3's own row says as much: *"Collector:
  /// only Projects with an assigned Task (BR-19)."*
  ///
  /// A `collectorId` parameter here would be a client-supplied scope on a
  /// server-enforced rule — at best redundant, at worst a value some future
  /// call site passes wrongly and nobody notices, because the backend ignores
  /// it. The token is attached by `AuthInterceptor` one layer down (ADR-035),
  /// which is why this feature needs nothing at all from `features/auth/`.
  ///
  /// Returns them in the order the backend supplied. No chapter specifies a
  /// sort, so none is imposed — but a cursor needs a **total** order, so the
  /// backend sorts `(created_at DESC, id DESC)` and A-183 records that the
  /// cursor forced the choice rather than a preference for it.
  ///
  /// ## It returns a `PagedResult`, not a list — A-184's fix
  ///
  /// `GET /v1/projects` has answered at most `DEFAULT_LIMIT` rows with a
  /// `meta.nextCursor` since Mission 7.3, and the client discarded `meta`
  /// entirely. An org with 51 Projects rendered 50, *"with no error, no empty
  /// state and nothing on either side reporting a truncation"*. A port that
  /// cannot say *"and there is more"* cannot fix that, whatever the caller
  /// does.
  ///
  /// [cursor] is the opaque value a previous page carried, or null for the
  /// first page. [limit] is Chapter 4.6 §1's `?limit=`, bounded by the
  /// backend's `MAX_LIMIT` of 200 — an out-of-range value is **rejected rather
  /// than clamped**, so asking for more than 200 is a failed request, not a
  /// silently smaller page.
  Future<PagedResult<Project>> fetchProjects({String? cursor, int? limit});

  /// The Tasks inside [projectId] — `GET /v1/projects/{id}/tasks`.
  ///
  /// Chapter 4.6 §3 calls this route *"the Constitution's own naming example,
  /// verbatim"*. Scoped by the same token context as [fetchProjects], so a
  /// Collector asking for an unassigned Project's Tasks is refused by the
  /// backend rather than filtered here.
  ///
  /// **That refusal is a 404, and it is thrown.** A-186 makes a Project outside
  /// the caller's reach *absent* rather than *forbidden* — `RESOURCE_NOT_FOUND`
  /// uniformly, because a 403 would confirm the id exists and answer the
  /// question a guessed id is asking. So an invisible Project raises a
  /// `NetworkException` carrying `RESOURCE_NOT_FOUND`; it does **not** come
  /// back as an empty list. A Project with no Tasks is the empty list, and the
  /// two answers must stay distinguishable — C-05 renders them differently.
  ///
  /// Paged on the same terms as [fetchProjects].
  Future<PagedResult<Task>> fetchTasks(
    String projectId, {
    String? cursor,
    int? limit,
  });
}
