import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../logging/providers/logger_provider.dart';
import '../firebase_initializer.dart';

/// Owner of Firebase initialisation.
///
/// Constructing the initialiser does nothing; [firebaseAppProvider] is what
/// starts the platform.
final Provider<FirebaseInitializer> firebaseInitializerProvider =
    Provider<FirebaseInitializer>(
      (Ref ref) => FirebaseInitializer(
        logger: ref.watch(loggerProvider),
        environment: AppConfig.environment,
      ),
    );

/// The initialised Firebase application.
///
/// Asynchronous, because initialisation is. Reading it twice returns the same
/// instance — the initialiser guarantees a single startup even under
/// concurrent reads.
///
/// ## Where this should be awaited
///
/// In the composition root, before `runApp`, not in a widget:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final ProviderContainer container = ProviderContainer();
///   await container.read(firebaseAppProvider.future);
///   runApp(
///     UncontrolledProviderScope(container: container, child: const VumpApp()),
///   );
/// }
/// ```
///
/// Awaiting it here means every Firebase product is usable from the first
/// frame, and an initialisation failure surfaces before any UI exists to be
/// confused by it.
///
/// **This wiring is not yet in place.** `lib/main.dart` was outside the
/// allowed paths of Mission 0.15, so nothing currently awaits this provider.
/// Until it is wired, Firebase initialises lazily on first read — which is
/// exactly the widget-triggered initialisation requirement 5 rules out.
///
/// ## Adding a Firebase product
///
/// Declare a provider for it that depends on this one, so ordering is
/// expressed as a dependency rather than assumed:
///
/// ```dart
/// final analyticsProvider = Provider<FirebaseAnalytics>((ref) {
///   ref.watch(firebaseAppProvider);
///   return FirebaseAnalytics.instance;
/// });
/// ```
///
/// No change to the initialiser is needed for any product.
final FutureProvider<FirebaseApp> firebaseAppProvider =
    FutureProvider<FirebaseApp>(
      (Ref ref) => ref.watch(firebaseInitializerProvider).initialize(),
    );
