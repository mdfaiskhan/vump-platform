import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/firebase/firebase_initializer.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';

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
/// **This wiring is in place.** `main.dart` awaits `_initializeFirebase`
/// before `runApp`, so nothing reaches a widget before the platform is up.
///
/// It was not, for a long time: `lib/main.dart` sat outside Mission 0.15's
/// allowed paths, so this comment recorded that Firebase initialised lazily on
/// first read — the widget-triggered initialisation requirement 5 rules out.
/// That gap is closed, and the sentence is kept in the past tense rather than
/// deleted, because the failure it describes is the one this provider exists
/// to prevent and a reader should know it was once real.
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
