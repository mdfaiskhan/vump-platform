import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// The repository the notifier drives.
///
/// **Overridden at the composition root**, because `application/` may not
/// import `data/` (ADR-022) and the implementation lives there. The same
/// inversion `authTokenSourceProvider` uses for the same reason (ADR-035):
///
/// ```dart
/// authRepositoryProvider.overrideWithValue(AuthRepositoryImpl()),
/// ```
///
/// Unimplemented rather than defaulted. A default would have to name a
/// concrete implementation, which is the import the layering forbids.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => throw UnimplementedError(
        'authRepositoryProvider must be overridden with an AuthRepository. '
        'features/auth/data/ provides AuthRepositoryImpl; see ADR-022 for why '
        'application/ cannot import it directly.',
      ),
    );

/// Live authentication state, and the sign-in actions that change it.
///
/// Volume 3 Chapter 3.9 §3 fixes the shape: `AsyncNotifier<AuthState>`. §2
/// fixes why — `AsyncValue` is the one pattern for anything that can be
/// loading, present or failed, so a screen handles all three branches or does
/// not compile.
///
/// ## Session state and operation outcomes are kept apart
///
/// [build] tracks the session. The sign-in methods **return a [Failure] rather
/// than throwing or writing to `state`**, and that separation is the design
/// decision worth knowing about.
///
/// A wrong password is not a broken session. If sign-in errors were pushed
/// through `AsyncError`, the app could not tell *"nobody is signed in"* from
/// *"someone just mistyped a password"* without unpacking the error object,
/// and a failed attempt would replace perfectly good session state with an
/// error. Returning the failure leaves [state] describing the session and only
/// the session, which is what the Role Router reads.
///
/// ## Where the conversion happens
///
/// This is the layer error-handling.md §26 names as the last that may catch an
/// `AppException`, and `Failure.fromException` is the single sanctioned
/// conversion. No exception reaches `presentation/`.
class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() {
    // The stream is the source of truth, not the restore call: Firebase emits
    // on sign-in, sign-out and token revocation, so listening keeps state
    // correct without this notifier polling or being told.
    final StreamSubscription<Session> subscription = _repository.sessionChanges
        .listen(
          _onSession,
          onError: (Object error, StackTrace stackTrace) {
            state = AsyncError<AuthState>(error, stackTrace);
          },
        );
    ref.onDispose(subscription.cancel);

    // Session.unknown carries no AuthState, so the first emission leaves the
    // notifier in AsyncLoading until the platform reports something real.
    // Awaiting the first non-unknown value here would stall build() for as
    // long as the restore takes; the stream sets state instead.
    return _restore();
  }

  /// Applies a session emitted by the repository.
  void _onSession(Session session) {
    final AuthState? next = AuthState.fromSession(session);
    if (next == null) {
      // Session.unknown — not yet determined. AsyncLoading is the same
      // statement in the vocabulary AsyncValue already gives the UI.
      state = const AsyncLoading<AuthState>();
      return;
    }
    state = AsyncData<AuthState>(next);
  }

  Future<AuthState> _restore() async {
    try {
      final Session session = await _repository.restoreSession();
      return AuthState.fromSession(session) ??
          const AuthState.unauthenticated();
    } on AppException {
      // A restore that fails is not an error state to show: it means nobody is
      // signed in as far as this launch is concerned. Mission 2.5 owns
      // distinguishing a lapsed session, which is what AuthState.expired is
      // for.
      return const AuthState.unauthenticated();
    }
  }

  /// Signs in with an email address and password.
  ///
  /// Returns `null` on success, or the [Failure] to render. `state` is not
  /// written here — the repository's stream reports the new session, so there
  /// is exactly one path by which authentication state changes.
  Future<Failure?> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _attempt(
      () =>
          _repository.signInWithEmailPassword(email: email, password: password),
    );
  }

  /// Signs in with the native Google account picker.
  Future<Failure?> signInWithGoogle() {
    return _attempt(_repository.signInWithGoogle);
  }

  /// Signs out, ending the session.
  Future<Failure?> signOut() {
    return _attempt(_repository.signOut);
  }

  /// Runs an authentication action, converting failure exactly once.
  Future<Failure?> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on AppException catch (exception) {
      return Failure.fromException(exception);
    }
  }
}

/// Live authentication state for the whole application.
final AsyncNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
