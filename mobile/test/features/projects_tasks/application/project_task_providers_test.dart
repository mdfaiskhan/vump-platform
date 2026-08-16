import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/projects_tasks/application/project_task_providers.dart';
import 'package:mobile/features/projects_tasks/application/projects_notifier.dart';

/// The seam fails loudly when nothing is bound to it.
///
/// This is the one behaviour that only exists because of a decision: the
/// provider throws rather than defaulting, so an unwired composition root is a
/// crash at the seam instead of an empty Projects list. Those two outcomes look
/// identical on screen and mean opposite things — "you have no assigned work"
/// versus "nobody wired this up" — which is why the throw is tested rather than
/// assumed.
void main() {
  ProviderContainer unwired() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('reading it unoverridden throws UnimplementedError', () {
    expect(
      () => unwired().read(projectTaskRepositoryProvider),
      throwsUnimplementedError,
    );
  });

  test('the message names the implementation and the reason', () {
    // A throw that does not say what to bind sends the next reader to the
    // provider's source to find out. Chapter 2.9's named-cause-and-fix rule
    // applied to a developer-facing failure.
    //
    // Matched rather than caught: `avoid_catching_errors` is an analyzer error
    // under ADR-021, and an `on UnimplementedError catch` here would be exactly
    // the "turning a programming mistake into a handled condition" that rule
    // exists to stop — even in a test.
    expect(
      () => unwired().read(projectTaskRepositoryProvider),
      throwsA(
        isA<UnimplementedError>()
            .having(
              (UnimplementedError e) => e.message,
              'message',
              contains('FakeProjectTaskRepository'),
            )
            .having(
              (UnimplementedError e) => e.message,
              'message',
              contains('features/projects_tasks/data/'),
            )
            .having(
              (UnimplementedError e) => e.message,
              'message',
              contains('ADR-022'),
            ),
      ),
    );
  });

  test('an unwired notifier fails at the seam, not with empty data', () async {
    // The failure the default is chosen to prevent: without the throw, this
    // would resolve to an empty list and C-04 would render "no projects".
    await expectLater(
      unwired().read(projectsProvider.future),
      throwsUnimplementedError,
    );
  });
}
