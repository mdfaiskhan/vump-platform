import 'package:firebase_core/firebase_core.dart';

import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/firebase/firebase_constants.dart';
import 'package:mobile/core/firebase/firebase_initialization_exception.dart';
import 'package:mobile/core/firebase/firebase_options_for_environment.dart';
import 'package:mobile/core/logging/app_logger.dart';

/// Brings up the Firebase platform, exactly once.
///
/// Owns nothing beyond initialisation. It does not know which Firebase
/// products the application uses, and gains no knowledge of them later — that
/// is what makes requirement 7 hold.
///
/// ## Why adding a product needs no change here
///
/// Every Firebase plugin resolves the already-initialised default app through
/// the SDK's own registry. Adding Auth, Crashlytics, Analytics or Messaging
/// means adding a dependency and a provider for that product; it does not mean
/// editing this class, because there is nothing product-specific in it to
/// edit.
///
/// ## Exactly once
///
/// Two callers racing during startup both find no app and both call
/// `Firebase.initializeApp`, which is an error rather than a no-op. The
/// in-flight `Future` is therefore held and handed to every concurrent caller,
/// the same pattern `DatabaseService` uses. A duplicate-app error from a
/// previous run in the same process is also tolerated: the existing instance
/// is adopted rather than treated as a failure.
///
/// ## Not a widget concern
///
/// Nothing here touches the widget tree. Initialisation is asynchronous and
/// belongs to the composition root, before `runApp`.
class FirebaseInitializer {
  FirebaseInitializer({
    required this.logger,
    required this.environment,
    this.timeout = FirebaseConstants.initializationTimeout,
  });

  /// Destination for lifecycle events.
  final AppLogger logger;

  /// Environment this build targets, per ADR-006.
  ///
  /// Recorded in the initialisation log so a support report shows which
  /// Firebase project a session was talking to.
  final AppEnvironment environment;

  /// Time allowed before initialisation is abandoned.
  final Duration timeout;

  FirebaseApp? _app;
  Future<FirebaseApp>? _initializing;

  /// Whether Firebase is initialised and usable.
  bool get isInitialized => _app != null;

  /// The initialised default application.
  ///
  /// Throws if [initialize] has not completed. Synchronous access for code
  /// already past startup; anything that might run earlier should await
  /// [initialize].
  FirebaseApp get app {
    final FirebaseApp? app = _app;
    if (app == null) {
      throw const FirebaseInitializationException(
        message:
            'Firebase has not been initialised. Await initialize() '
            'before reading app.',
      );
    }
    return app;
  }

  /// Initialises Firebase, or returns the application already initialised.
  ///
  /// Safe to call repeatedly and safe to call concurrently.
  Future<FirebaseApp> initialize() {
    final FirebaseApp? existing = _app;
    if (existing != null) {
      return Future<FirebaseApp>.value(existing);
    }
    return _initializing ??= _initialize();
  }

  Future<FirebaseApp> _initialize() async {
    final DateTime startedAt = DateTime.now();

    try {
      final FirebaseApp app = await Firebase.initializeApp(
        options: firebaseOptionsForEnvironment(environment),
      ).timeout(timeout);

      _app = app;

      logger.info(
        'Firebase initialised for ${environment.label} '
        '(project "${app.options.projectId}") in '
        '${DateTime.now().difference(startedAt).inMilliseconds}ms.',
      );

      return app;
    } on FirebaseException catch (error, stackTrace) {
      // A duplicate-app error means the platform is already up — adopt it
      // rather than fail. This happens on hot restart, where Dart state is
      // discarded but the native SDK is not.
      if (error.code == 'duplicate-app') {
        final FirebaseApp app = Firebase.app(FirebaseConstants.defaultAppName);
        _app = app;
        logger.debug('Firebase was already initialised; adopted it.');
        return app;
      }

      _initializing = null;
      throw _failure(
        'Firebase rejected initialisation (${error.code}).',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      _initializing = null;
      throw _failure(
        'Firebase could not be initialised for ${environment.label}.',
        error,
        stackTrace,
      );
    }
  }

  /// Builds, logs and returns the exception for a failed initialisation.
  FirebaseInitializationException _failure(
    String message,
    Object cause,
    StackTrace stackTrace,
  ) {
    final FirebaseInitializationException exception =
        FirebaseInitializationException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
    logger.error('Firebase initialisation failed.', error: exception);
    return exception;
  }
}
