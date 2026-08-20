import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';

/// What a failed write puts on screen — Mission 7.8 item 3.
///
/// Driven through `AdminCreateScaffold` rather than through a whole create
/// screen: the scaffold takes a `Failure` directly and is the shared chrome
/// both A-04 and A-05 render, so this covers both write surfaces without a
/// repository, a router or a provider container.
///
/// **This banner had no test at all before now**, which is how it came to
/// render a backend diagnostic to end users without anyone noticing.
void main() {
  Future<void> pump(WidgetTester tester, Failure? failure) {
    return tester.pumpWidget(
      MaterialApp(
        home: AdminCreateScaffold(
          title: 'New Project',
          form: GlobalKey<FormState>(),
          saving: false,
          failure: failure,
          submitLabel: 'Create Project',
          onSubmit: () async {},
          fields: const <Widget>[],
        ),
      ),
    );
  }

  testWidgets('a refusal says the role is the problem, not the network', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const Failure(code: ErrorCode.authForbidden, message: 'refused'),
    );

    expect(find.text("You don't have permission to do this."), findsOneWidget);
    expect(
      find.text(
        'Ask your organisation admin to check your role, then sign in again.',
      ),
      findsOneWidget,
    );

    // Retrying is exactly what will not help here, so the copy must not
    // suggest it — Chapter 2.9 §4.3 asks for the recovery action that exists.
    expect(find.textContaining('try again'), findsNothing);
  });

  testWidgets('a transient fault still says to try again', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Failure(code: ErrorCode.networkUnavailable));

    expect(find.text("This couldn't be saved."), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('the backend diagnostic never reaches the screen', (
    WidgetTester tester,
  ) async {
    // The defect this replaces, asserted directly. `VumpApi._named` rebuilds a
    // refused request's exception from the Chapter 4.6 envelope, so this is
    // the literal string an Admin used to read on a 403.
    const String diagnostic =
        'The backend refused Creating a project: AUTH_FORBIDDEN — Not '
        'permitted: this endpoint requires the admin role.';

    await pump(
      tester,
      const Failure(code: ErrorCode.authForbidden, message: diagnostic),
    );

    expect(find.text(diagnostic), findsNothing);
    expect(find.textContaining('AUTH_FORBIDDEN'), findsNothing);
    expect(find.textContaining('backend'), findsNothing);
  });

  testWidgets('a message on a transient failure is ignored too', (
    WidgetTester tester,
  ) async {
    // Not only the forbidden case. Any message would be a diagnostic, because
    // nothing on the write path produces user-facing prose.
    await pump(
      tester,
      const Failure(
        code: ErrorCode.networkServerError,
        message: 'Server returned 500 for POST https://internal.example/v1/x.',
      ),
    );

    expect(find.textContaining('https://'), findsNothing);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('no failure renders no banner', (WidgetTester tester) async {
    await pump(tester, null);

    expect(find.textContaining("couldn't be saved"), findsNothing);
    expect(find.textContaining('permission'), findsNothing);
  });
}
