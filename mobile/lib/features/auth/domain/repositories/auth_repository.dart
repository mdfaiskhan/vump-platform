import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

/// Throws `AuthenticationException` on every failure path — never a raw
/// platform exception, and never a `Failure`.
///
/// `Failure` is not throwable: it does not implement `Exception`, and
/// `only_throw_errors` is an analyzer **error** under ADR-021. It is the type
/// that *crosses out* of infrastructure, not the one that travels up the stack.
///
/// See error-handling.md §26: `data/` throws `AppException` subclasses, and the
/// exception-to-`Failure` conversion happens exactly once, in `application/`,
/// via `Failure.fromException`.
abstract interface class AuthRepository {
  Stream<Session> get sessionChanges;

  Future<Session> restoreSession();

  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<User> signInWithGoogle();

  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    required String inviteCode,
  });

  Future<User> signUpWithGoogle({required String inviteCode});

  Future<void> signOut();
}
