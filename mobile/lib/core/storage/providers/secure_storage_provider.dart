import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/storage/interfaces/secure_storage_repository.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';

/// The application's secure storage.
///
/// Typed as [SecureStorageRepository] rather than as the concrete service, so
/// that consumers depend on the abstraction and not on the implementation —
/// the rule ADR-008 exists to enforce. A caller that reads this provider
/// cannot reach `SecureStorageService`, and therefore cannot reach
/// `flutter_secure_storage`.
///
/// Per ADR-003 there is no singleton and no service locator. Override it in a
/// `ProviderScope` to substitute an in-memory fake:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
///   ],
///   child: const VumpApp(),
/// )
/// ```
///
/// That override is the only practical way to exercise storage in a widget
/// test, since the platform channels behind the real implementation are not
/// available under `flutter test`.
final Provider<SecureStorageRepository> secureStorageProvider =
    Provider<SecureStorageRepository>((Ref ref) => SecureStorageService());
