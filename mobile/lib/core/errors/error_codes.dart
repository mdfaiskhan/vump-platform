/// The closed set of error conditions the application can report.
///
/// Every exception and every failure carries one of these. The enum is the
/// stable vocabulary that infrastructure maps *into* and that application code
/// switches *on* — a layer must never branch on an exception's message string
/// or on a third-party error type.
///
/// Each case carries a [code], a stable identifier suitable for logs and
/// telemetry. It is deliberately not a user-facing message: presenting an error
/// is a localisation concern keyed by this value, not a property of it.
///
/// Codes are grouped by the layer that raises them. Adding a case is routine;
/// changing the [code] string of an existing case is not, because it breaks
/// every log query and dashboard that references it.
enum ErrorCode {
  // ---------------------------------------------------------------------------
  // Unclassified
  // ---------------------------------------------------------------------------

  /// No more specific code applies. A frequent occurrence of this in logs
  /// indicates a gap in the taxonomy rather than a class of error.
  unknown('UNKNOWN'),

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  /// No usable connection to the network.
  networkUnavailable('NETWORK_UNAVAILABLE'),

  /// The request exceeded its time budget.
  networkTimeout('NETWORK_TIMEOUT'),

  /// The request was cancelled before it completed.
  networkCancelled('NETWORK_CANCELLED'),

  /// The server returned a 5xx response.
  networkServerError('NETWORK_SERVER_ERROR'),

  /// The server rejected the request as malformed — a 4xx that is not one of
  /// the more specific cases below.
  networkBadRequest('NETWORK_BAD_REQUEST'),

  /// The requested resource does not exist.
  networkNotFound('NETWORK_NOT_FOUND'),

  /// The request conflicts with the current state of the resource.
  networkConflict('NETWORK_CONFLICT'),

  /// The caller exceeded a rate limit or quota.
  networkRateLimited('NETWORK_RATE_LIMITED'),

  /// The response could not be decoded into the expected shape.
  networkSerialization('NETWORK_SERIALIZATION'),

  // ---------------------------------------------------------------------------
  // Authentication and authorisation
  // ---------------------------------------------------------------------------

  /// The caller is not signed in.
  authUnauthenticated('AUTH_UNAUTHENTICATED'),

  /// The supplied credentials were rejected.
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),

  /// A previously valid session is no longer valid.
  authSessionExpired('AUTH_SESSION_EXPIRED'),

  /// The token could not be refreshed.
  authTokenRefreshFailed('AUTH_TOKEN_REFRESH_FAILED'),

  /// The caller is authenticated but not permitted to perform the action.
  authForbidden('AUTH_FORBIDDEN'),

  /// The account exists but is disabled or suspended.
  authAccountDisabled('AUTH_ACCOUNT_DISABLED'),

  /// The organisation invite code does not exist, or has already been redeemed.
  authInviteCodeInvalid('AUTH_INVITE_CODE_INVALID'),

  /// The organisation invite code exists but is past its expiry.
  authInviteCodeExpired('AUTH_INVITE_CODE_EXPIRED'),

  /// Sign-up was attempted with an email address that is already registered.
  authEmailAlreadyInUse('AUTH_EMAIL_ALREADY_IN_USE'),

  /// The user dismissed an external sign-in flow before it completed.
  ///
  /// Not a failure. It is in this taxonomy so that a deliberate cancellation
  /// can be told apart from one, and reported as neither an error nor a
  /// success.
  authSignInCancelled('AUTH_SIGN_IN_CANCELLED'),

  // ---------------------------------------------------------------------------
  // Storage — local database, secure storage, files
  // ---------------------------------------------------------------------------

  /// A read from local storage failed.
  storageReadFailed('STORAGE_READ_FAILED'),

  /// A write to local storage failed.
  storageWriteFailed('STORAGE_WRITE_FAILED'),

  /// A delete from local storage failed.
  storageDeleteFailed('STORAGE_DELETE_FAILED'),

  /// The requested key or record is absent.
  storageNotFound('STORAGE_NOT_FOUND'),

  /// Stored data could not be read in the shape it was written.
  storageCorrupted('STORAGE_CORRUPTED'),

  /// The storage backend could not be reached or opened.
  storageUnavailable('STORAGE_UNAVAILABLE'),

  /// The platform denied access to the storage backend.
  storagePermissionDenied('STORAGE_PERMISSION_DENIED'),

  // ---------------------------------------------------------------------------
  // Device — hardware capability the application cannot supply in software
  // ---------------------------------------------------------------------------

  /// The camera could not be opened or queried.
  ///
  /// The hardware exists but the platform refused it — in use by another
  /// application, disabled by policy, or a driver-level failure.
  deviceCameraUnavailable('DEVICE_CAMERA_UNAVAILABLE'),

  /// No rear camera is present.
  ///
  /// BR-01 opens the rear camera only, so a device without one cannot record
  /// at all. Distinct from [deviceCameraUnavailable]: nothing is wrong, the
  /// hardware is simply absent.
  deviceRearCameraAbsent('DEVICE_REAR_CAMERA_ABSENT'),

  /// The device cannot reach the wide-angle field of view BR-02 requires.
  ///
  /// Tier 3 of Volume 5.1 §2's capability ladder — neither a dedicated
  /// ultra-wide lens nor a primary sensor that zooms out to 0.5x/0.6x. A
  /// named, honest block rather than a silent recording at the wrong field of
  /// view.
  deviceWideAngleUnsupported('DEVICE_WIDE_ANGLE_UNSUPPORTED'),

  /// Camera permission was refused by the operating system.
  ///
  /// Split out from [deviceCameraUnavailable] by Mission 3.8, because FR-CHK-01
  /// and Volume 2 Ch. 2.7's C-08 require the Checklist to name the specific
  /// failed check and its remedy — and "enable camera access in Settings" is a
  /// different sentence from "the camera is in use by another app".
  devicePermissionCameraDenied('DEVICE_PERMISSION_CAMERA_DENIED'),

  /// Microphone permission was refused by the operating system.
  ///
  /// Separate from [devicePermissionCameraDenied] because they are separate
  /// grants and BR-03 requires both — a Collector who granted one and refused
  /// the other must be told which.
  devicePermissionMicrophoneDenied('DEVICE_PERMISSION_MICROPHONE_DENIED'),

  /// The battery level could not be read.
  ///
  /// FR-CHK-03 requires the level be verified before recording starts, so a
  /// reading that fails is a failed check rather than a skipped one — the
  /// Checklist cannot confirm what it could not measure.
  deviceBatteryUnreadable('DEVICE_BATTERY_UNREADABLE'),

  /// The connection status could not be read.
  ///
  /// Distinct from having no connection: [deviceNetworkStatusUnreadable] means
  /// the platform did not answer, where "offline" is a perfectly good answer
  /// that FR-CHK-04 reports and never blocks on.
  deviceNetworkStatusUnreadable('DEVICE_NETWORK_STATUS_UNREADABLE'),

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Input failed validation for a reason with no more specific code.
  validationInvalidInput('VALIDATION_INVALID_INPUT'),

  /// A required value was absent or empty.
  validationRequiredField('VALIDATION_REQUIRED_FIELD'),

  /// A value was well-formed but outside its permitted range.
  validationOutOfRange('VALIDATION_OUT_OF_RANGE'),

  /// A value did not match its required format.
  validationInvalidFormat('VALIDATION_INVALID_FORMAT'),

  /// A value collides with one that already exists.
  validationAlreadyExists('VALIDATION_ALREADY_EXISTS');

  const ErrorCode(this.code);

  /// Stable identifier for logs, telemetry and dashboards.
  ///
  /// Safe to persist and to query on. Never rendered to a user.
  final String code;
}
