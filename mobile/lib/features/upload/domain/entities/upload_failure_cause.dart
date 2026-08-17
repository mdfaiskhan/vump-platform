/// Why one attempt at Volume 5 Chapter 5.10's pipeline stopped.
///
/// Volume 2 Chapter 2.9 §2's first principle: *"Never fail silently. Every
/// failure state … must name the specific cause and the specific fix … A
/// generic 'Something went wrong' is treated as a defect, not an acceptable
/// fallback."* §3's copy table makes the standard concrete — not *"Upload
/// failed."* but *"Chunk 5 failed to upload. Check your connection and
/// retry."*
///
/// This enum is the cause half. The copy half is C-11's, and belongs to the
/// mission that renders it; producing a named cause here is what makes that
/// possible without the screen guessing.
///
/// ## Each member carries Chapter 5.13 §1's classification
///
/// The chapter fixes three handling classes, and [isTransient] is where a
/// cause says which it is. Nothing new is invented: every member maps onto one
/// of the three rows of that table.
enum UploadFailureCause {
  /// A-068 Guard 1 — the chunk's `identity` group does not name real things.
  ///
  /// **Terminal, device-side.** Nothing about the stored row will change on a
  /// retry, so retrying could only fail identically.
  ///
  /// This is the cause that fires for every chunk this application has
  /// recorded to date: four of `MetadataIdentity`'s five fields carry the
  /// unsourced empty-string sentinel until `features/projects_tasks/`, the
  /// `collector_id` inversion and a `device_id` source exist.
  identityIncomplete(isTransient: false),

  /// FR-META-09 says this cannot happen; it is reported rather than assumed.
  ///
  /// **Terminal, device-side.** A chunk with no metadata row cannot produce
  /// Chapter 5.10 §1 step 4's document.
  metadataMissing(isTransient: false),

  /// The local `.mp4` is gone or unreadable.
  ///
  /// **Terminal, device-side** — Chapter 5.13 §1 names *"Local file
  /// missing/corrupted"* in this class explicitly.
  fileUnavailable(isTransient: false),

  /// The session has no Task to register under, so step 1's URL cannot be
  /// addressed.
  ///
  /// **Terminal, device-side.** See `SessionRegistrar`: `LocalSession.taskId`
  /// is null on every row this application has written.
  sessionUnregisterable(isTransient: false),

  /// The backend answered, and refused.
  ///
  /// **Terminal, server-side** — Chapter 5.13 §1: *"Backend rejects with a 4xx
  /// (e.g. auth/permission error) … a repeated identical request would fail
  /// identically."*
  rejectedByBackend(isTransient: false),

  /// The backend's response did not match Chapter 4.6's contract.
  ///
  /// **Terminal, server-side.** A missing `s3_object_key`, an empty
  /// `upload_urls`, or a `chunk_id` naming a different chunk. Retrying an
  /// identical request would produce the same malformed answer, and continuing
  /// past it would upload bytes under an identity nobody chose.
  malformedResponse(isTransient: false),

  /// The connection dropped, timed out, or S3 answered 5xx.
  ///
  /// **Transient** — Chapter 5.13 §1's first row verbatim, handled by §2's
  /// backoff and *"never surfaced to the Collector as Failed until attempts
  /// are exhausted"*.
  transportFailure(isTransient: true),

  /// Local storage could not be read or written.
  ///
  /// **Transient.** A claim or a status write that failed is a fault in this
  /// device's storage rather than in the chunk, and the same chunk may well
  /// succeed on the next attempt.
  storageFailure(isTransient: true);

  const UploadFailureCause({required this.isTransient});

  /// Whether Chapter 5.13 §2's automatic backoff applies.
  ///
  /// False means Chapter 5.13 §1's *"Not retried automatically — surfaces
  /// immediately as Failed with a specific, named cause"*. A manual retry
  /// (FR-UPL-07) is still permitted for either, and §3 is explicit that it
  /// *"is not a bypass of Section 1's terminal-failure classification"* — a
  /// terminal cause simply fails again, still named.
  final bool isTransient;
}
