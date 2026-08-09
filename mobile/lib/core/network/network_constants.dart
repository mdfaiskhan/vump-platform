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
