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

  /// Creates an account.
  ///
  /// [inviteCode] is optional since amendment A-056. Without one the account
  /// joins the default organisation; with one it joins that code's
  /// organisation. The role is `collector` either way — no invite code grants
  /// admin, and no self-signup path can.
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  });

  /// Creates an account from a Google identity. [inviteCode] is optional.
  Future<User> signUpWithGoogle({String? inviteCode});

  Future<void> signOut();
}
