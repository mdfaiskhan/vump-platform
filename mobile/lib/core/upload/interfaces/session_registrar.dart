/// Turns a local session into the backend session id Chapter 5.10 §1 needs.
///
/// Volume 5 Chapter 5.10 §1 step 1 is `POST /v1/sessions/{id}/chunks`. That
/// `{id}` is **not** the local session UUID this app mints at session start —
/// it is a backend session, created by Volume 4 Chapter 4.6 §4's
/// `POST /v1/tasks/{id}/sessions`.
///
/// ## The Task arrives as a parameter — F32
///
/// The contract used to be `remoteSessionId(String localSessionId)`, and
/// **could not be implemented as written**. The route is nested under a Task,
/// and from a local session id alone the only source for one is
/// `LocalSession.taskId` — owned by `features/recording/`, which the intended
/// implementor could not import. That was A-100's deadlock.
///
/// F17 resolved it by putting the Task on the chunk, so the caller already
/// holds it by the time it reaches step 1. Passing it is therefore not a
/// widening of this port's responsibility; it is the port asking for what its
/// caller was given.
///
/// ## Where the implementation lives, and why not where this doc used to say
///
/// `features/upload/data/`, beside `ChunkUploadApiImpl` — F33.
///
/// This file previously said the implementation was *"owed to whichever
/// mission builds `features/projects_tasks/`"*, on the reasoning that the Task
/// belonged to that feature. Once the Task id arrives as a `String` parameter,
/// an implementation needs **nothing** from `features/projects_tasks/`: it
/// posts to a URL and reads an id back, which is exactly what
/// `ChunkUploadApiImpl` already does four times over.
///
/// The port stays in `core/` even so. `features/upload/application/` declares
/// what it needs and may not import `data/` (ADR-022 §5.3), so the contract has
/// to sit somewhere both can see.
///
/// ## Idempotent, and the repetition is load-bearing
///
/// A pipeline that runs once per chunk asks for the same session's id many
/// times — 38 for a full recording, more with retries. An implementation that
/// created a session per call would fragment one recording across many backend
/// sessions, so `POST /v1/tasks/{id}/sessions` is idempotent on
/// `client_session_id` (F5) and answers **200 with the existing row** rather
/// than an error.
///
/// **It is deliberately not cached — F34.** The repetition costs two Lambda
/// invocations and four Data API calls against an upload that moves 633 MB in
/// 38 parts, which is noise. And `startSession` calls `assertAssigned` every
/// time: Chapter 4.8 §3 says a removed assignment *"immediately excludes that
/// Task from all future queries, even if the mobile app's local cache hasn't
/// refreshed yet"*, so **each registration is a live authorization re-check**.
/// Caching it would let a Collector whose assignment was revoked mid-session
/// upload the rest of the recording anyway.
///
/// `SESSION_ALREADY_REGISTERED` is not the ordinary repeat. It fires only when
/// the same `client_session_id` is re-presented under a **different** Task,
/// which would either move a recording between Tasks mid-flight or silently
/// hand back a session under a Task the caller did not ask for.
abstract interface class SessionRegistrar {
  /// The backend session id for a local session, registering it if needed.
  ///
  /// [localSessionId] is the device's UUID and becomes the request's
  /// `client_session_id` — F5's idempotency key, unique per collector.
  ///
  /// [taskId] is the Task the session records against, from
  /// `UploadableChunk.taskId`. **Nullable, and a null is terminal.** It is null
  /// for every session recorded before Mission 7.4 step 5 and for any session
  /// started without a Task selected, and the implementation throws a
  /// `ValidationException` carrying `ErrorCode.validationRequiredField` rather
  /// than inventing one — Chapter 5.13 §1's **terminal, device-side** class,
  /// surfaced immediately with a named cause and never retried, because
  /// nothing about the stored row will change.
  ///
  /// [startedAt] is when capture actually began, sent as F15's optional
  /// `started_at`. Worth sending rather than letting the column default to
  /// `now()`: a deferred upload may register hours after the recording, and the
  /// server clock would then stamp the session with the upload time.
  ///
  /// Throws a `NetworkException` if the call itself fails.
  Future<String> remoteSessionId({
    required String localSessionId,
    required String? taskId,
    required DateTime startedAt,
  });
}
