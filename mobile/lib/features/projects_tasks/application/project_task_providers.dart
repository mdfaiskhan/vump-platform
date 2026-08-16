import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/domain/repositories/project_task_repository.dart';

/// The repository this feature's notifiers drive.
///
/// **Overridden at the composition root**, because `application/` may not
/// import `data/` (ADR-022 §5.3) and every implementation lives there. This is
/// the same inversion `authRepositoryProvider` has used since Mission 2.2 and
/// `chunkQueueSourceProvider` since Mission 4.1 — Volume 3 Chapter 3.2's own
/// internal ADR-006 (Dependency Injection) is the Volume-side record, and this
/// repository's records for it are ADR-003 and ADR-022.
///
/// (Volume 3's internal ADR-006 is **not** this repository's ADR-006, which is
/// Centralised Application Configuration. Fourth instance of open item 34's
/// citation collision — see A-077's lookup table.)
///
/// Unimplemented rather than defaulted. A default would have to name a
/// concrete class, which is the import the layering forbids, and a silent
/// default is worse here than a loud throw: it would present an empty Projects
/// list as *"you have no assigned work"* rather than as *"nothing was wired
/// up"*, and those are the two answers a Collector must never see confused.
final Provider<ProjectTaskRepository> projectTaskRepositoryProvider =
    Provider<ProjectTaskRepository>(
      (Ref ref) => throw UnimplementedError(
        'projectTaskRepositoryProvider must be overridden with a '
        'ProjectTaskRepository. features/projects_tasks/data/ provides '
        'FakeProjectTaskRepository until Mission 7 supplies a real one; see '
        'ADR-022 for why application/ cannot import it directly.',
      ),
    );
