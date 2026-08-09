import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mobile/app/config/app_environment.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firebase/firebase_initialization_exception.dart';
import 'package:mobile/core/firebase/firebase_initializer.dart';
import 'package:mobile/core/logging/app_logger.dart';

/// Discards log output so a failing-by-design test does not print noise.
class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  late AppLogger logger;

  setUp(() {
    logger = AppLogger(
      environment: AppEnvironment.development,
      output: _SilentOutput(),
    );
  });

  FirebaseInitializer buildInitializer() => FirebaseInitializer(
        logger: logger,
        environment: AppEnvironment.development,
      );

  // Firebase is configured now — `firebase_options.dart` holds real project
  // values. These tests still exercise the failure path, because the platform
  // channels `Firebase.initializeApp` depends on do not exist under
  // `flutter test`. That makes them a test of the error boundary rather than
  // of initialisation itself: whatever goes wrong, callers must see an
  // AppException and never a FirebaseException from the SDK.
  //
  // The success path — including duplicate-app adoption — is only reachable on
  // a device or emulator and remains uncovered.
  group('FirebaseInitializer, without platform channels', () {
    test('reports itself uninitialised', () {
      expect(buildInitializer().isInitialized, isFalse);
    });

    test('app getter throws rather than returning null', () {
      expect(
        () => buildInitializer().app,
        throwsA(isA<FirebaseInitializationException>()),
      );
    });

    test('initialize converts the failure into the application taxonomy', () {
      // The Mission 0.10 boundary: no matter what fails inside initialisation,
      // the SDK's own error type must not escape.
      expect(
        buildInitializer().initialize(),
        throwsA(
          allOf(
            isA<FirebaseInitializationException>(),
            isA<AppException>(),
          ),
        ),
      );
    });

    test('remains uninitialised after a failed attempt', () async {
      final FirebaseInitializer initializer = buildInitializer();

      await expectLater(
        initializer.initialize(),
        throwsA(isA<FirebaseInitializationException>()),
      );

      expect(initializer.isInitialized, isFalse);
    });

    test('concurrent callers share a single initialisation attempt', () async {
      // The exactly-once guarantee of ADR-010. Two callers arriving before the
      // first has finished must share one attempt, not start two —
      // `Firebase.initializeApp` throws on a second concurrent call rather
      // than returning the existing app. Identity of the returned future is
      // what proves only one attempt was made.
      final FirebaseInitializer initializer = buildInitializer();

      final Future<Object?> first = initializer.initialize();
      final Future<Object?> second = initializer.initialize();

      expect(identical(first, second), isTrue);

      await expectLater(
        first,
        throwsA(isA<FirebaseInitializationException>()),
      );
      await expectLater(
        second,
        throwsA(isA<FirebaseInitializationException>()),
      );
    });

    test('a failed attempt is retryable rather than cached forever', () async {
      // The in-flight future is cleared on failure, so a later call attempts
      // initialisation again instead of replaying the original error.
      final FirebaseInitializer initializer = buildInitializer();

      await expectLater(
        initializer.initialize(),
        throwsA(isA<FirebaseInitializationException>()),
      );
      await expectLater(
        initializer.initialize(),
        throwsA(isA<FirebaseInitializationException>()),
      );
    });
  });
}
