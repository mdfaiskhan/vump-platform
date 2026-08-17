/// Fixed values used by the networking layer.
///
/// Header names, media types, timeout defaults and the HTTP status codes the
/// error mapping branches on. Per ADR-007 these are permitted in source: none
/// is a secret, and all are discoverable by inspecting the application's
/// traffic.
///
/// No base URL appears here. Endpoints vary by environment and are resolved by
/// `NetworkConfig`.
abstract final class NetworkConstants {
  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  /// Time allowed to establish a connection.
  ///
  /// Short: failing to connect is usually a dead network, and a long wait
  /// leaves the user staring at a spinner that will not resolve.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Time allowed between bytes while reading a response.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Time allowed to transmit a request body.
  ///
  /// Matches [receiveTimeout]. Uploads that need longer must raise it per
  /// request rather than by widening the default for every call.
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Time allowed to transmit a chunk part to S3 — **none, deliberately**.
  ///
  /// `null` is Dio's "no send timeout". This is a documented decision taken in
  /// Mission 4.2, not an oversight, and amendment A-072 records it.
  ///
  /// ## Nothing in the specification produces a number
  ///
  /// A send timeout is a duration, and a duration for a transfer can only come
  /// from a **rate**. All fifteen Volumes were searched for one — `mbps`,
  /// `kbps`, `bandwidth`, `throughput`, `connection speed`, `upload speed`,
  /// `minimum connection`, `2G`/`3G`/`4G`/`LTE`. There is none. The word
  /// *timeout* itself appears exactly once in the entire specification, in
  /// Volume 5 Chapter 5.13 §1's failure table, as an example of a transient
  /// failure — with no value attached.
  ///
  /// The nearest requirements do not answer it either. NFR-AVL-02's *"< 30
  /// seconds"* is how fast an upload **resumes** after connectivity returns,
  /// not how fast it transfers; Volume 9 Chapter 9.4 §1 has no throughput row;
  /// and Volume 0 Chapter 0.1 §4 lists upload latency as a metric to be
  /// *measured after launch* *"under normal network conditions"*, a phrase it
  /// never defines. Volume 1 Chapter 1.4's own preamble concedes its targets
  /// are provisional until pilot data exists.
  ///
  /// ## It could not be derived from a byte count either
  ///
  /// Volume 4 Chapter 4.6 §5's registration response returns `upload_urls` as
  /// a **list**, and Chapter 4.10 §2 confirms the Lambda generates that set.
  /// So the backend chooses the part count, and part size is
  /// `fileSizeBytes / uploadUrls.length` — known only at runtime and different
  /// per chunk. No compile-time constant can describe it.
  ///
  /// ## Why a guessed value would be worse than none
  ///
  /// Chapter 5.13 §1 classifies a timeout as **transient**, and §2 grants a
  /// chunk six automatic attempts. A value set too low against a slow but
  /// working field connection would not surface as a configuration mistake —
  /// it would burn the retry budget and then present as *"Failed"* to the
  /// Collector, with the true cause invisible. An absent timeout fails
  /// visibly, when it fails at all.
  ///
  /// ## What bounds a transfer instead
  ///
  /// [connectTimeout] still bounds reaching the host, [receiveTimeout] still
  /// bounds S3's response, and `TransferHandle` gives the pipeline explicit
  /// cancellation (Chapter 5.10 §4). What is genuinely unbounded is a socket
  /// that accepts bytes forever without completing — named, not solved.
  ///
  /// ## The gap this leaves open
  ///
  /// **A field bandwidth-floor NFR does not exist and should.** Establishing
  /// one is a product decision about the conditions Collectors work in, not an
  /// engineering one, so it is deferred to its own conversation rather than
  /// settled inside an implementation mission. Carried as an open item; this
  /// constant becomes derivable the moment that NFR exists.
  static const Duration? uploadSendTimeout = null;

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';

  /// Prefix for a bearer credential in the [authorizationHeader].
  static const String bearerPrefix = 'Bearer ';

  /// Media type sent and expected by default.
  static const String jsonContentType = 'application/json';

  // ---------------------------------------------------------------------------
  // Logging safety
  // ---------------------------------------------------------------------------

  /// Headers whose values must never reach a log.
  ///
  /// ADR-007 forbids credentials in source; logging one puts it back in plain
  /// text. The logging interceptor replaces these values with
  /// [redactedPlaceholder]. Compared case-insensitively, because HTTP header
  /// names are case-insensitive and a server may echo `authorization`.
  static const List<String> redactedHeaders = <String>[
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-refresh-token',
  ];

  /// Substituted for the value of a redacted header.
  static const String redactedPlaceholder = '[REDACTED]';

  /// Longest request or response body written to a log, in characters.
  ///
  /// Bodies are truncated rather than omitted: the opening of a payload is
  /// usually enough to diagnose a shape mismatch, while a large response would
  /// otherwise bury every surrounding line.
  static const int maxLoggedBodyLength = 2000;

  // ---------------------------------------------------------------------------
  // Status codes
  // ---------------------------------------------------------------------------

  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int tooManyRequests = 429;

  /// Lowest status code treated as a server-side failure.
  static const int internalServerError = 500;

  /// Lowest status code treated as a client-side failure.
  static const int clientErrorFloor = 400;
}
