import 'package:isar/isar.dart';

part 'local_session.g.dart';

/// Volume 5 Chapter 5.8 §1's `local_sessions` table.
///
/// Mirrors Volume 4's `sessions` (Chapter 4.4 §5): id, task_id, collector_id,
/// started_at, status, notes. Chapter 5.8 §1 adds one constraint of its own —
/// *"Only this Collector's own sessions — never another Collector's"* — which
/// is a property of what is written here, not a column.
///
/// ## Why this lives in `features/recording/data/` and not `core/database/`
///
/// ADR-030 confines `isar` to the module that owns it, and the CI job's own
/// comment sets the precedent: *"a Firebase **product** belongs to the module
/// that consumes it, which is what makes `features/auth/` the replaceable unit
/// rather than `core/`"*. The same split applies here — `core/database/` owns
/// the engine, its lifecycle and its migrations; a feature owns its
/// collections. `DatabaseMetadata`, the one collection already in `core/`,
/// says of itself that it is *"Infrastructure, not a feature model"*.
///
/// **This is not yet permitted.** ADR-009 §"Isar does not escape the layer"
/// still says *"no file outside `core/database/` imports `isar`"*, and CI's
/// `Architecture boundaries` job still enforces it. ADR-039 is drafted to
/// supersede that clause and is **Proposed, not approved** — so until it is,
/// this file is a defect against a binding ADR, and the CI job failing on it
/// is the correct signal rather than a nuisance.
///
/// ## The id is a string, not Isar's auto-increment
///
/// [sessionId] is the UUID Chapter 5.14 §3 requires, generated once at session
/// start, and it is the identity everything else references — the S3 key
/// embeds it and the backend joins on it. Isar's own [Id] is a separate
/// surrogate; making the UUID the meaningful key and indexing it unique keeps
/// the two from being confused.
@collection
class LocalSession {
  /// Creates a stored session.
  LocalSession();

  /// Isar's surrogate key. Never referenced by anything outside the database.
  Id id = Isar.autoIncrement;

  /// The session UUID (Ch. 5.14 §3) — the identity the rest of the system uses.
  @Index(unique: true, replace: true)
  late String sessionId;

  /// From Volume 4's `sessions.task_id`.
  ///
  /// Null until `TaskContext` is implemented — `features/projects_tasks/` is
  /// unbuilt, and Mission 3.6's A-062 records the gap. Stored nullable rather
  /// than omitted so a session written today can be back-filled rather than
  /// re-created.
  String? taskId;

  /// From Volume 4's `sessions.collector_id`. Null for the same reason.
  String? collectorId;

  /// When the Collector tapped Start.
  late DateTime startedAt;

  /// `'in_progress'` or `'complete'` — Volume 4's `sessions.status`, FR-SES-02.
  late String status;

  /// Collector-authored, Phase 2 (FR-SEC-01). Always null today.
  String? notes;
}
