import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/projects_tasks/application/write_failure.dart';

/// The write-side mirror of `read_failure_test.dart`.
///
/// The classification is one branch, so these tests are less about the switch
/// than about the two properties around it: that a refusal is distinguished
/// from a fault, and that neither answer is derived from the failure's message.
void main() {
  test('AUTH_FORBIDDEN is "you may not do this"', () {
    expect(
      classifyWriteFailure(
        const Failure(code: ErrorCode.authForbidden, message: 'refused'),
      ),
      ProjectTaskWriteFailure.notPermitted,
    );
  });

  test('everything else is unavailable', () {
    for (final ErrorCode code in <ErrorCode>[
      ErrorCode.networkUnavailable,
      ErrorCode.networkTimeout,
      ErrorCode.networkServerError,
      ErrorCode.networkBadRequest,
      ErrorCode.authUnauthenticated,
      ErrorCode.unknown,
    ]) {
      expect(
        classifyWriteFailure(Failure(code: code)),
        ProjectTaskWriteFailure.unavailable,
        reason: '$code should not be reported as a permission problem',
      );
    }
  });

  test('a validation refusal is unavailable, not its own case', () {
    // Deliberate, and the reason is in write_failure.dart: the form validates
    // before submitting, so a server-side validation refusal means the two
    // validators disagree. That is a defect rather than something the person
    // can correct, and telling them to check a field the form just accepted
    // sends them to fix something that is not broken.
    expect(
      classifyWriteFailure(
        const Failure(code: ErrorCode.validationInvalidInput),
      ),
      ProjectTaskWriteFailure.unavailable,
    );
  });

  test('the message is never consulted', () {
    // The property that matters most here, and the one a future edit is most
    // likely to break by reaching for `failure.message` again "just for this
    // case". Two failures with the same code and opposite messages must
    // classify identically.
    const Failure withDiagnostic = Failure(
      code: ErrorCode.authForbidden,
      message:
          'The backend refused Creating a project: AUTH_FORBIDDEN — Not '
          'permitted: this endpoint requires the admin role.',
    );
    const Failure withNothing = Failure(code: ErrorCode.authForbidden);

    expect(
      classifyWriteFailure(withDiagnostic),
      classifyWriteFailure(withNothing),
    );
    expect(
      classifyWriteFailure(withDiagnostic),
      ProjectTaskWriteFailure.notPermitted,
    );
  });
}
