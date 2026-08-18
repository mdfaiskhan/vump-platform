import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';
import 'package:mobile/core/network/s3_transfer_client.dart';
import 'package:mobile/core/network/vump_api.dart';

/// Network configuration for the environment this build targets.
///
/// The seam where ADR-007's ownership split is realised: `AppConfig` supplies
/// environment identity, and `NetworkConfig` turns it into a base URL and
/// timeouts. Override this in a `ProviderScope` to point tests at a stub
/// server without touching a call site.
final Provider<NetworkConfig> networkConfigProvider = Provider<NetworkConfig>(
  (Ref ref) => NetworkConfig.forEnvironment(AppConfig.environment),
);

/// Supplies the credential `AuthInterceptor` attaches to each request.
///
/// **Must be overridden before any request is made.** The implementation lives
/// in `features/auth/data/`, and `core/` may not import a feature (ADR-022),
/// so the composition root introduces the two:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     authTokenSourceProvider.overrideWithValue(FirebaseAuthTokenSource()),
///   ],
///   child: const VumpApp(),
/// )
/// ```
///
/// Unimplemented rather than defaulted to a no-token source, and the reasoning
/// is the same as `databaseDirectoryProvider`'s: failing at the override point
/// is easier to diagnose than the alternative. Here the alternative is worse
/// than a misplaced file — a silent "no token" default would send every
/// request unauthenticated, and the symptom would be a server 401 that reads
/// as an expired session rather than as unwired configuration.
///
/// See ADR-035.
final Provider<AuthTokenSource> authTokenSourceProvider =
    Provider<AuthTokenSource>(
      (Ref ref) => throw UnimplementedError(
        'authTokenSourceProvider must be overridden with an AuthTokenSource '
        'before any authenticated request is made. features/auth/data/ '
        'provides FirebaseAuthTokenSource; see ADR-035.',
      ),
    );

/// The application's HTTP client.
///
/// Depends on [networkConfigProvider], `loggerProvider` and
/// [authTokenSourceProvider], so overriding any of them reconfigures the
/// client without reconstructing it here.
final Provider<DioClient> dioClientProvider = Provider<DioClient>(
  (Ref ref) => DioClient(
    config: ref.watch(networkConfigProvider),
    logger: ref.watch(loggerProvider),
    tokenSource: ref.watch(authTokenSourceProvider),
  ),
);

/// The configured `Dio` instance.
///
/// Provided for the cases [DioClient]'s verb methods do not cover — multipart
/// uploads, downloads, streamed responses. Prefer [dioClientProvider]: reading
/// this one means catching `DioException` yourself, since the unwrapping that
/// guarantees a `NetworkException` lives on the client rather than in the
/// interceptor chain.
final Provider<Dio> dioProvider = Provider<Dio>(
  (Ref ref) => ref.watch(dioClientProvider).dio,
);

/// The client used for Volume 5 Chapter 5.10 §1 step 2's direct-to-S3 upload.
///
/// **Deliberately not derived from [dioClientProvider].** It is a separate
/// client with no `AuthInterceptor`, because a presigned S3 request carries
/// its own SigV4 authorisation and S3 rejects one that also presents a
/// conflicting `Authorization` header — and with no `LoggingInterceptor`,
/// because a presigned URL is a bearer credential in a query string. See
/// `S3TransferClient` for both arguments in full.
///
/// It reads [loggerProvider] and nothing else. There is no token source in
/// scope, which is the point: no code path here can send a Vump credential to
/// Amazon.
final Provider<S3TransferClient> s3TransferClientProvider =
    Provider<S3TransferClient>(
      (Ref ref) => S3TransferClient(logger: ref.watch(loggerProvider)),
    );

/// The Vump backend API, over [dioClientProvider].
///
/// Published here rather than constructed at each call site so that a test can
/// override one provider instead of threading a client through constructors —
/// the same reason `dioClientProvider` exists.
final Provider<VumpApi> vumpApiProvider = Provider<VumpApi>(
  (Ref ref) => VumpApi(client: ref.watch(dioClientProvider)),
);
