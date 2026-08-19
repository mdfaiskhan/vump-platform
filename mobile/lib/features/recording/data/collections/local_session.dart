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
  /// **Written since Mission 7.4 step 5**, from the Task the Collector chose in
  /// C-06. Null on every row recorded before that, and on any session started
  /// without a selection — which A-068's Guard 1 then refuses at upload rather
  /// than attributing to a guess.
  ///
  /// This is the **durability boundary for Task context** (F38). The upload
  /// path reads it here at claim time, hours or days and any number of
  /// relaunches after the recording ended; the in-memory selection that
  /// produced it lives for one navigation and is deliberately not persisted.
  String? taskId;

  /// The Task's owning Project — Chapter 4.5 §2's `project_id`.
  ///
  /// Not a column in Volume 4's `sessions` table, which reaches a Project by
  /// joining through `tasks`. It is stored here anyway because the **metadata
  /// document is assembled on the device**, possibly offline, and Chapter 4.5
  /// §2's `identity` group names `project_id` directly — deriving it would need
  /// the join, and the join is the backend's.
  ///
  /// Additive and nullable, so it needs no migration: `migration.dart` records
  /// that *"Isar migrates additive change silently — a new collection or
  /// property simply appears"*. Existing rows read null, which is correct —
  /// they were recorded when no Project was known.
  String? projectId;

  /// From Volume 4's `sessions.collector_id`.
  ///
  /// Still null, and unlike [taskId] that is not a gap: the backend derives the
  /// collector from the verified token on every route (Chapter 4.8), so nothing
  /// reads this column. Kept because Chapter 5.8 §1 mirrors the table.
  String? collectorId;

  /// When the Collector tapped Start.
  late DateTime startedAt;

  /// `'in_progress'` or `'complete'` — Volume 4's `sessions.status`, FR-SES-02.
  late String status;

  /// Collector-authored, Phase 2 (FR-SEC-01). Always null today.
  String? notes;
}
