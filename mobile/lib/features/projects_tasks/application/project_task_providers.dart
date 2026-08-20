import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/domain/repositories/project_task_admin_repository.dart';
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
        'ProjectTaskRepositoryImpl over VumpApi, which main.dart binds; '
        'test/features/projects_tasks/data/fakes/ provides '
        'FakeProjectTaskRepository for tests. See ADR-022 for why '
        'application/ cannot import either directly.',
      ),
    );

/// The Admin's write path, overridden at the composition root.
///
/// Same inversion and the same reason as [projectTaskRepositoryProvider]:
/// `application/` may not import `data/` (ADR-022 §5.3).
///
/// Mission 5.2.1 built the interface and the fake; Mission 5.2.2's Admin CRUD
/// screens were the first consumers, and Mission 7.4 replaced the fake with
/// `ProjectTaskAdminRepositoryImpl` over the real API. It is declared
/// now rather than with its first caller because A-099's whole argument for
/// splitting read from write is that a Collector-side notifier must be unable
/// to reach a write method — and that guarantee is only real once the two
/// providers are distinct.
///
/// The throw matters more here than on the read side. An unwired read presents
/// as an empty list; an unwired write would present as *"your Project was
/// saved"* over nothing at all, which is the false confirmation Chapter 2.7's
/// A-06 refuses by name.
final Provider<ProjectTaskAdminRepository> projectTaskAdminRepositoryProvider =
    Provider<ProjectTaskAdminRepository>(
      (Ref ref) => throw UnimplementedError(
        'projectTaskAdminRepositoryProvider must be overridden with a '
        'ProjectTaskAdminRepository. features/projects_tasks/data/ provides '
        'ProjectTaskAdminRepositoryImpl over VumpApi, which main.dart binds; '
        'test/features/projects_tasks/data/fakes/ provides '
        'FakeProjectTaskAdminRepository for tests. See ADR-022 for why '
        'application/ cannot import either directly.',
      ),
    );
