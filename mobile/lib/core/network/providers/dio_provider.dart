import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../logging/providers/logger_provider.dart';
import '../dio_client.dart';
import '../network_config.dart';

/// Network configuration for the environment this build targets.
///
/// The seam where ADR-007's ownership split is realised: `AppConfig` supplies
/// environment identity, and `NetworkConfig` turns it into a base URL and
/// timeouts. Override this in a `ProviderScope` to point tests at a stub
/// server without touching a call site.
final Provider<NetworkConfig> networkConfigProvider = Provider<NetworkConfig>(
  (Ref ref) => NetworkConfig.forEnvironment(AppConfig.environment),
);

/// The application's HTTP client.
///
/// Depends on [networkConfigProvider] and `loggerProvider`, so overriding
/// either reconfigures the client without reconstructing it here.
final Provider<DioClient> dioClientProvider = Provider<DioClient>(
  (Ref ref) => DioClient(
    config: ref.watch(networkConfigProvider),
    logger: ref.watch(loggerProvider),
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
