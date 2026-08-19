import 'package:mobile/core/errors/exceptions/network_exception.dart';

/// Why a Projects or Tasks read failed, in the terms a screen must render.
///
/// ## Why this exists in `application/` rather than in the screen
///
/// error-handling.md §26 makes `application/` *"the last layer that may"* hold
/// an `AppException`, and `presentation/` a layer no exception may reach. A
/// screen that inspected a `NetworkException`'s status code directly would be
/// doing the conversion in the wrong layer and branching on a transport detail
/// at the same time.
///
/// So the classification happens here, once, and a screen branches on this
/// enum.
///
/// ## Why the distinction is worth drawing at all
///
/// Until Mission 7.4 both cases rendered *"couldn't be loaded. Check your
/// connection and try again."* Against `FakeProjectTaskRepository` that was
/// accurate, because the fake answered an unknown Project with an **empty
/// list** and there was no other failure to have.
///
/// The real repository does not. A-186 makes a Project the caller cannot see
/// report `404 RESOURCE_NOT_FOUND` — absent rather than forbidden, so that a
/// guessed id is not confirmed — and that is not a connection problem. Telling
/// a Collector to check their connection over a stale link sends them to fix
/// something that is not broken, which is the *"named cause and fix"* rule in
/// Chapter 2.9 §2 failing in the direction that is hardest to notice.
enum ProjectTaskReadFailure {
  /// The Project or its Tasks are not visible to this caller.
  ///
  /// BR-19 makes *"not assigned to you"* and *"does not exist"* deliberately
  /// indistinguishable from the client, so the copy for this case must claim
  /// neither.
  notVisible,

  /// Anything else — no connection, a timeout, a server fault, a bad payload.
  unavailable,
}

/// Classifies the object an `AsyncError` carried.
///
/// [error] is `AsyncValue.error`, which is whatever was thrown: a
/// `NetworkException` from `data/`, or — for a defect rather than a refusal —
/// anything at all. A non-exception is [ProjectTaskReadFailure.unavailable],
/// because a screen has nothing better to say about a bug than that the data
/// is not there.
ProjectTaskReadFailure classifyReadFailure(Object? error) {
  if (error is! NetworkException) {
    return ProjectTaskReadFailure.unavailable;
  }

  // The envelope's own code first, since F29 made it structural. Chapter 4.6
  // §1 requires errors to *"always carry a specific code, never a bare HTTP
  // status alone"*, and reading the code rather than the status is what honours
  // that: a 404 from a misrouted request is not RESOURCE_NOT_FOUND and must not
  // be reported as an invisible Project.
  if (error.backendCode == 'RESOURCE_NOT_FOUND') {
    return ProjectTaskReadFailure.notVisible;
  }

  return ProjectTaskReadFailure.unavailable;
}
