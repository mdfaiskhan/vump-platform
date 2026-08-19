import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/projects_tasks/application/page_size.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/domain/entities/paged_result.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';

/// The Collector's assigned Projects — FR-PT-03, rendered by C-04.
///
/// Volume 3 Chapter 3.9 §3 fixes the shape and §2 fixes why: `AsyncValue` is
/// the one pattern for anything that can be loading, present or failed, so a
/// screen handles all three branches or does not compile.
///
/// ## Why this holds no filter and no sort
///
/// BR-19's assignment scope is applied by the backend from the bearer token
/// (Volume 4 Chapter 4.8; Chapter 4.2 §3's injected `WHERE` clause), and no
/// chapter specifies an ordering for C-04. A sort invented here would be a
/// product decision taken by a notifier.
///
/// ## `refresh` exists because a pull-to-refresh has nowhere else to live
///
/// FR-PT-06 makes offline browsing a *Should Have* and no cache is built yet
/// (`local_task_cache` is assigned to this feature by ADR-039 §3 and
/// deliberately not implemented — open item 2), so today every read is a live
/// one and [refresh] is the only way a Collector gets newer data than the one
/// fetched at build.
///
/// ## The cursor is private, and the state stays a plain list — F25
///
/// The repository returns a `PagedResult`; this notifier keeps its
/// `nextCursor` in a
/// private field and publishes only the accumulated items. Seven things read
/// `projectsProvider` and none of them changes type, which is the point: a
/// screen renders Projects, and *where the next page starts* is bookkeeping
/// that belongs to whatever does the reading.
///
/// [hasMore] is the narrow getter that exposes the one bit a screen genuinely
/// needs — whether to offer "load more" — without widening the state itself.
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  String? _nextCursor;
  bool _loadingMore = false;

  @override
  Future<List<Project>> build() async {
    final PagedResult<Project> page = await ref
        .watch(projectTaskRepositoryProvider)
        .fetchProjects(limit: projectTaskPageSize);
    _nextCursor = page.nextCursor;
    return page.items;
  }

  /// Whether a further page exists on the backend.
  ///
  /// Read from the last page's cursor rather than derived from the item count.
  /// The backend fetches one row more than asked for so that a *full* page is
  /// not mistaken for a non-final one; re-deriving the answer from
  /// `items.length` here would throw that away and produce one empty final page
  /// every time the total is an exact multiple of the page size.
  bool get hasMore => _nextCursor != null;

  /// Appends the next page, if there is one.
  ///
  /// **It does not enter the loading state.** A screen showing 200 Projects
  /// must not blank while the 201st arrives — `AsyncNotifier`'s loading state
  /// replaces the value, and that is right for [refresh] and wrong here.
  /// A failure is likewise not published as an `AsyncError`: the pages already
  /// on screen are still valid, and replacing them with an error would discard
  /// good data because more of it could not be fetched. The gap this leaves —
  /// a silently failed "load more" — is stated rather than hidden, and is what
  /// the returned `bool` reports to the caller.
  ///
  /// Returns true when a page was appended.
  Future<bool> loadMore() async {
    final String? cursor = _nextCursor;
    if (cursor == null || _loadingMore) {
      return false;
    }

    _loadingMore = true;
    try {
      final PagedResult<Project> page = await ref
          .read(projectTaskRepositoryProvider)
          .fetchProjects(cursor: cursor, limit: projectTaskPageSize);
      _nextCursor = page.nextCursor;
      state = AsyncValue<List<Project>>.data(<Project>[
        ...state.valueOrNull ?? const <Project>[],
        ...page.items,
      ]);
      return true;
    } on Object {
      // Swallowed deliberately, per the paragraph above. The caller learns
      // nothing was appended; the list it is already rendering is untouched.
      return false;
    } finally {
      _loadingMore = false;
    }
  }

  /// Re-reads the Projects from the first page, showing the loading state.
  ///
  /// `AsyncValue.guard` is what puts a thrown `NetworkException` into
  /// [state] as an `AsyncError` rather than letting it escape an
  /// `application/` method — error-handling.md §26's *"must not let an
  /// exception reach `presentation/`"*.
  ///
  /// The cursor resets first. A refresh that kept it would append page two of
  /// a list it had just discarded.
  Future<void> refresh() async {
    _nextCursor = null;
    state = const AsyncValue<List<Project>>.loading();
    state = await AsyncValue.guard(() async {
      final PagedResult<Project> page = await ref
          .read(projectTaskRepositoryProvider)
          .fetchProjects(limit: projectTaskPageSize);
      _nextCursor = page.nextCursor;
      return page.items;
    });
  }
}

/// Live Projects state for C-03's dashboard and C-04's list.
final AsyncNotifierProvider<ProjectsNotifier, List<Project>> projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
      ProjectsNotifier.new,
    );
