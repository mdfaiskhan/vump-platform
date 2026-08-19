/// The `identity` group of Volume 4 Chapter 4.5 §2's wire shape.
///
/// **Every field is nullable, and that is the whole point of this type.**
///
/// The domain's `MetadataIdentity` makes all five required, because *"a chunk
/// that cannot say which Task it belongs to or who recorded it is not a valid
/// record"*. The stored row makes all five nullable, because Isar needs a
/// default constructor. `ChunkRecordMapper` refused to write a reverse mapper
/// between them precisely because narrowing back would mean substituting empty
/// strings, and *"an empty `collector_id` that reached an upload would be
/// indistinguishable from a real one"*.
///
/// This type dissolves that: it narrows nothing. A stored null stays null, a
/// stored blank stays blank, and [isComplete] rejects both. The reverse mapper
/// `ChunkRecordMapper` declined to write is safe to write against *this*
/// shape, which is why Mission 4.2 could write it without contradicting the
/// reasoning that deferred it.
class MetadataIdentityDocument {
  /// Creates the identity group.
  const MetadataIdentityDocument({
    this.sessionId,
    this.projectId,
    this.taskId,
    this.collectorId,
    this.deviceId,
  });

  /// `identity.session_id` — **the LOCAL session UUID as written, and the
  /// BACKEND's by the time it reaches the wire.**
  ///
  /// See [withRemoteSessionId]. A-207.
  final String? sessionId;

  /// `identity.project_id` — no source until `features/projects_tasks/` exists.
  final String? projectId;

  /// `identity.task_id` — no source until `features/projects_tasks/` exists.
  final String? taskId;

  /// `identity.collector_id` — `users.id` from `POST /v1/auth/verify`, not the
  /// Firebase uid. A-206.
  final String? collectorId;

  /// `identity.device_id` — F19's install-scoped UUID.
  final String? deviceId;

  /// This identity with [remoteSessionId] in place of the local one — A-207.
  ///
  /// ## Why a rewrite exists at all, and why it is only this field
  ///
  /// The document is assembled at **chunk finalization**, which happens while
  /// recording and may happen with no network at all. The only session id the
  /// device has then is its own, and F5 makes the two deliberately distinct:
  /// `sessions.client_session_id` is the device's, `sessions.id` is the
  /// backend's.
  ///
  /// `functions/metadata/` resolves a chunk's true identity from a join and
  /// refuses a document that disagrees — and it joins on `s.id`. So the stored
  /// value is right for the device and wrong for the wire, and **every metadata
  /// POST would be refused** without this.
  ///
  /// A general `copyWith` is deliberately not offered. BR-22 makes
  /// system-generated metadata immutable once written, and this is the single
  /// field whose correct value differs between where it is stored and where it
  /// is sent. A method that could rewrite any of the five would make that
  /// distinction invisible at the call site.
  MetadataIdentityDocument withRemoteSessionId(String remoteSessionId) {
    return MetadataIdentityDocument(
      sessionId: remoteSessionId,
      projectId: projectId,
      taskId: taskId,
      collectorId: collectorId,
      deviceId: deviceId,
    );
  }

  /// Whether all five fields name something real.
  ///
  /// **This is A-068 Guard 1's actual test.** Null and blank both fail, and
  /// they fail for the same reason: Volume 8 Chapter 8.6 §2 collects identity
  /// *"to attribute footage to the correct Collector/device"*, and BR-22 makes
  /// system-generated metadata immutable once written — so a chunk stored with
  /// a blank attribution could never be corrected. Permanently unattributable
  /// evidence is the opposite of what the field is collected for.
  ///
  /// False for every chunk this application has recorded to date: four of the
  /// five carry `MetadataIdentity.unsourced`, the empty string.
  bool get isComplete =>
      _present(sessionId) &&
      _present(projectId) &&
      _present(taskId) &&
      _present(collectorId) &&
      _present(deviceId);

  /// The names of the fields that are missing, in schema order.
  ///
  /// Ch. 2.9 §2 forbids a failure that does not *"name the specific cause"*,
  /// and §3's copy table shows the standard: not "Upload failed" but which
  /// thing is wrong. A refusal reporting only *"identity incomplete"* would be
  /// the generic message that chapter treats as a defect.
  List<String> get missingFields => <String>[
    if (!_present(sessionId)) 'session_id',
    if (!_present(projectId)) 'project_id',
    if (!_present(taskId)) 'task_id',
    if (!_present(collectorId)) 'collector_id',
    if (!_present(deviceId)) 'device_id',
  ];

  static bool _present(String? value) => value != null && value.isNotEmpty;

  /// Chapter 4.5 §2's `identity` object.
  Map<String, Object?> toJson() => <String, Object?>{
    'session_id': sessionId,
    'project_id': projectId,
    'task_id': taskId,
    'collector_id': collectorId,
    'device_id': deviceId,
  };
}
