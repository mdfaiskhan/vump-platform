/// Turns a local session id into the backend session id Chapter 5.10 §1 needs.
///
/// Volume 5 Chapter 5.10 §1 step 1 is `POST /v1/sessions/{id}/chunks`. That
/// `{id}` is **not** the local session UUID this app mints at session start —
/// it is a backend session, created by Volume 4 Chapter 4.6 §4's
/// `POST /v1/tasks/{id}/sessions`, which Chapter 5.10 never mentions and which
/// nothing in this application can call.
///
/// ## Why it cannot be called: the task id does not exist
///
/// That endpoint is nested under a Task. `LocalSession.taskId` is nullable and
/// **null on every row this application has ever written**, because
/// `features/projects_tasks/` is unbuilt and `MetadataIdentity.taskId` carries
/// the unsourced sentinel. There is no value to put in the URL.
///
/// ## Why this is a port rather than a call in `features/upload/`
///
/// Whatever eventually satisfies this needs a Task, and Tasks belong to
/// `features/projects_tasks/`. ADR-022 R3 forbids `features/upload/` importing
/// it *"at any layer, in either direction"*, so the requirement is stated here
/// on neutral ground and that feature satisfies it when it exists — ADR-040's
/// pattern, applied to a third pair.
///
/// ## Declared before it can be implemented, deliberately
///
/// This follows `ChunkFinalizer`'s precedent exactly. That port was declared
/// while all three of its collaborators were unbuilt, because *"declaring the
/// port now rather than later is what lets Chapter 5.3's machine be finished
/// and fully tested on its own"*. The same holds here: Chapter 5.10's pipeline
/// is complete and testable end to end with this stubbed, and incomplete
/// without it.
///
/// **No implementation exists in `lib/`, and `sessionRegistrarProvider` throws
/// until one does.** A fake in `test/` satisfies it for the suite; nothing
/// fake is bound in a build, because Volume 11 Chapter 11.1's **M8 — APIs
/// Integrated** gate requires that *"no fake/mock repository remains wired
/// into a release build"*.
///
/// **Owed to whichever mission builds `features/projects_tasks/`.**
abstract interface class SessionRegistrar {
  /// The backend session id for [localSessionId], registering it if needed.
  ///
  /// Idempotent by contract. Chapter 5.10 §3's idempotency argument covers
  /// registration being *"safe to repeat"*, and a chunk pipeline that runs
  /// once per chunk will ask for the same session's id many times — an
  /// implementation that created a session per call would fragment one
  /// recording across many backend sessions.
  ///
  /// Throws a `ValidationException` carrying
  /// `ErrorCode.validationRequiredField` when the local session has no task to
  /// register under. That is Chapter 5.13 §1's **terminal, device-side**
  /// class: not retried, surfaced immediately with a named cause. Retrying
  /// could not help, because nothing about the stored row will change.
  ///
  /// Throws a `NetworkException` if the call itself fails.
  Future<String> remoteSessionId(String localSessionId);
}
