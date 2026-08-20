import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';

/// Why a Projects or Tasks **write** failed, in the terms a screen must render.
///
/// The mirror of `ProjectTaskReadFailure`, and it exists for the same reason at
/// the same layer: error-handling.md §26 makes `application/` *"the last layer
/// that may"* hold an `AppException`, and a screen branching on an `ErrorCode`
/// would be doing the conversion in the wrong place.
///
/// ## What it replaces, and why that was worse than a missing case
///
/// Until Mission 7.8 the write banner rendered `failure.message` directly, with
/// *"Check your connection and try again."* as the fallback when that was null.
///
/// **It was almost never null.** `VumpApi._named` rebuilds a refused request's
/// exception from the Chapter 4.6 envelope, so an Admin whose role no longer
/// permits a write read this on screen, verbatim:
///
/// ```text
/// This couldn't be saved.
/// The backend refused Creating a project: AUTH_FORBIDDEN — Not permitted:
/// this endpoint requires the admin role.
/// ```
///
/// A developer diagnostic, carrying an internal error code, shown to the person
/// using the app. `Failure`'s own documentation says the opposite should happen
/// — *"Presentation should prefer text resolved from `code`, since only that
/// is localisable"* — and Chapter 2.9 §2 principle 1 treats a generic fallback
/// as a defect, which the branch beneath it was.
///
/// So the message is no longer rendered at all. The code decides the copy.
///
/// ## Two cases, deliberately, and the same two shapes reads have
///
/// The test is not *"how many ways can a write fail"* — it is **how many
/// different things can the person usefully DO**. Reads settled on two for that
/// reason and writes divide the same way: either this account may not perform
/// this action, or something transient went wrong and retrying is the answer.
///
/// A third case for `REQUEST_INVALID` was considered and rejected. The form
/// validates before submitting, so a server-side validation refusal means the
/// two validators disagree — a defect rather than something a person can
/// correct, and telling them to check a field the form just accepted sends them
/// to fix something that is not broken. It arrives as [unavailable] and the
/// prompt to try again is at least honest about there being nothing else to do.
enum ProjectTaskWriteFailure {
  /// The backend refused this action for this caller.
  ///
  /// `AUTH_FORBIDDEN` — `requireRole` or an org-scope check said no. Retrying
  /// cannot help, so the copy for this case must not suggest it.
  ///
  /// **Reachable without anything being broken.** The role guard is a
  /// navigation correction rather than a security boundary (ADR-037), and the
  /// authorizer resolves `Caller.role` from the `users` table. An account whose
  /// role changed sees the Admin surfaces its session was built with until that
  /// session is rebuilt — Mission 7.8 narrowed that window by sourcing the
  /// client's role from the same table, and did not close it.
  notPermitted,

  /// Anything else — no connection, a timeout, a server fault, a bad payload.
  unavailable,
}

/// Classifies a [Failure] returned by a write.
///
/// Takes a `Failure` rather than a raw `Object?`, unlike
/// `classifyReadFailure`: a write path returns one already, because
/// `AdminProjectTaskNotifier._attempt` converts exactly once at the
/// boundary. A read surfaces through
/// `AsyncValue.error`, which is whatever was thrown, so its classifier has to
/// accept anything. Same layer, same purpose, different input by circumstance.
ProjectTaskWriteFailure classifyWriteFailure(Failure failure) {
  return switch (failure.code) {
    ErrorCode.authForbidden => ProjectTaskWriteFailure.notPermitted,
    _ => ProjectTaskWriteFailure.unavailable,
  };
}
