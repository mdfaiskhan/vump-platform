import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/errors/exceptions/validation_exception.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/core/upload/interfaces/session_registrar.dart';

/// Registers a recording session with the backend — Chapter 4.6 §4.
///
/// **The first implementation this port has ever had.** It was declared in
/// Mission 4.2 and `sessionRegistrarProvider` has thrown ever since, which is
/// why no chunk has reached `uploading` on a device: constructing the pipeline
/// threw, so `UploadDispatcher` holds it behind a function rather than a field
/// and touches the seam only when there is a chunk to send.
///
/// ## It lives here rather than in `features/projects_tasks/` — F33
///
/// The port's own doc used to owe this to that feature, because the route is
/// nested under a Task. Once F32 made the Task id a parameter, an
/// implementation needs nothing from that feature at all: it posts to a URL and
/// reads an id back, which is what `ChunkUploadApiImpl` beside it already does
/// four times over. Both are `features/upload/data/` because
/// `features/upload/` is what calls them.
///
/// ## Every call is a real request — F34
///
/// No cache, in memory or on disk. `POST /v1/tasks/{id}/sessions` is idempotent
/// on `client_session_id` and answers 200 with the existing row on a repeat, so
/// correctness does not need one; and the repetition is **load-bearing**,
/// because `startSession` re-runs `assertAssigned` every time. Chapter 4.8 §3
/// makes a removed assignment take effect immediately *"even if the mobile
/// app's local cache hasn't refreshed yet"* — so caching the id would let a
/// Collector whose assignment was revoked mid-session upload the rest of the
/// recording anyway.
class SessionRegistrarImpl implements SessionRegistrar {
  /// Creates the registrar over [backend].
  const SessionRegistrarImpl({required VumpApi backend}) : _api = backend;

  final VumpApi _api;

  @override
  Future<String> remoteSessionId({
    required String localSessionId,
    required String? taskId,
    required DateTime startedAt,
  }) async {
    // Before any network call, and terminal. Chapter 5.13 §1's device-side
    // class: retrying cannot help, because nothing about the stored session
    // row will change. Chapter 2.9 §2 forbids a failure that does not name its
    // cause, so this says which value is missing and what it means.
    if (taskId == null || taskId.isEmpty) {
      throw const ValidationException(
        errorCode: ErrorCode.validationRequiredField,
        message:
            'This recording was made before a Task was chosen, so it cannot '
            'be uploaded. Its footage is still on this device.',
        field: 'task_id',
      );
    }

    final Map<String, Object?> data = await _api.post(
      '/tasks/$taskId/sessions',
      what: 'the recording session',
      body: <String, Object?>{
        // F5's idempotency key. The device's own session UUID, which the
        // backend stores as `client_session_id` and constrains unique per
        // collector — so a repeat converges on one row instead of fragmenting
        // one recording across many backend sessions.
        'client_session_id': localSessionId,
        // F15. Absent would mean "use the server clock", and a deferred upload
        // registering hours after capture would stamp the session with the
        // upload time. Sent as UTC ISO-8601, which the backend parses with
        // `optionalPastInstant` and rejects only if it is in the future.
        'started_at': startedAt.toUtc().toIso8601String(),
      },
    );

    final Object? id = data['id'];
    if (id is! String || id.isEmpty) {
      // The response shape is Chapter 4.6 §4's `SessionDto`, whose `id` is
      // NOT NULL. An absent one means the contract changed, and continuing
      // would put an empty session id into the next request's URL.
      throw const NetworkException(
        errorCode: ErrorCode.networkSerialization,
        message: 'The backend returned no session id for this recording.',
      );
    }
    return id;
  }
}
