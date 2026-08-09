import '../../app/config/app_environment.dart';
import 'network_constants.dart';

/// What the application talks to, resolved for one environment.
///
/// Per ADR-007, network configuration lives in `core/network/` rather than in
/// `app/config/`: a base URL describes infrastructure, not product identity.
/// The dependency runs one way — this class reads [AppEnvironment]; nothing in
/// `app/config/` may import from here.
///
/// Holds no secret. Base URLs, timeouts and non-secret headers are permitted
/// in source by ADR-007; API keys, tokens and credentials are not, and must
/// never be added to this class.
class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    this.connectTimeout = NetworkConstants.connectTimeout,
    this.receiveTimeout = NetworkConstants.receiveTimeout,
    this.sendTimeout = NetworkConstants.sendTimeout,
  });

  /// Resolves the configuration for [environment].
  ///
  /// Exhaustive over the enum, so adding an environment is a compile error
  /// here rather than a silent fallback to the wrong host.
  factory NetworkConfig.forEnvironment(AppEnvironment environment) {
    return NetworkConfig(baseUrl: baseUrlFor(environment));
  }

  /// Root of every request path.
  final String baseUrl;

  /// Time allowed to establish a connection.
  final Duration connectTimeout;

  /// Time allowed between bytes while reading a response.
  final Duration receiveTimeout;

  /// Time allowed to transmit a request body.
  final Duration sendTimeout;

  /// Headers sent with every request.
  ///
  /// Carries no credential. The `Authorization` header is attached per request
  /// by `AuthInterceptor`, never configured statically — a token has a
  /// lifetime, and configuration does not.
  Map<String, String> get defaultHeaders => const <String, String>{
    NetworkConstants.contentTypeHeader: NetworkConstants.jsonContentType,
    NetworkConstants.acceptHeader: NetworkConstants.jsonContentType,
  };

  /// Chunk storage bucket for [environment].
  ///
  /// **Derived, not listed.** ADR-011 fixes the naming rule as
  /// `vump-platform-{slug}`, so the name is computed from
  /// [AppEnvironment.slug] rather than restated in a table. A second table
  /// would be a second source of truth, and `infrastructure/aws/config/
  /// environments.json` already holds the backend's copy.
  ///
  /// Informational only, per Volume 7, Chapter 7.10 §2. The application never
  /// addresses S3 by bucket — it uploads to presigned URLs the backend
  /// returns (Volume 4, Chapter 4.10 §2). This exists for diagnostics and
  /// support reports, never to construct a request.
  static String chunkBucketFor(AppEnvironment environment) =>
      'vump-platform-${environment.slug}';

  /// Base URL for each environment.
  ///
  /// **These are placeholders.** The `.example` top-level domain is reserved
  /// by IANA for documentation and never resolves, so a build that reaches the
  /// network with one of these unmodified fails loudly instead of silently
  /// contacting the wrong host. Replace all three with the real endpoints
  /// before any build ships.
  static String baseUrlFor(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development => 'https://api.development.vump.example',
      AppEnvironment.staging => 'https://api.staging.vump.example',
      AppEnvironment.production => 'https://api.vump.example',
    };
  }
}
