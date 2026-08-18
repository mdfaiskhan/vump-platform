import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/network/network_constants.dart';

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
  /// Development is real. **Staging and production are still placeholders**,
  /// and that is correct rather than unfinished: no API Gateway exists in
  /// either environment, because `infrastructure/terraform/environments/`
  /// contains only `dev`. The `.example` top-level domain is reserved by IANA
  /// and never resolves, so a staging or production build that reaches the
  /// network fails loudly instead of silently contacting the wrong host —
  /// which is the property worth keeping until there is something real to
  /// point at.
  ///
  /// The development URL is API Gateway's generated invoke URL:
  /// `https://{restApiId}.execute-api.{region}.amazonaws.com/{stage}`. The id
  /// is assigned by AWS, not chosen, so it is an opaque value that changes if
  /// the REST API is ever destroyed and recreated. A custom domain would fix
  /// that and is deferred — it needs a registered domain, and `vump.example`
  /// is reserved and unregisterable.
  static String baseUrlFor(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development =>
        'https://32mar2hwsk.execute-api.ap-south-1.amazonaws.com/dev',
      AppEnvironment.staging => 'https://api.staging.vump.example',
      AppEnvironment.production => 'https://api.vump.example',
    };
  }
}
