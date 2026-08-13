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

  /// True once a session has been observed, so a later loss can be told apart
  /// from never having signed in.
  ///
  /// Firebase reports both as the same event — `authStateChanges()` emits null
  /// for a revoked refresh token and for a signed-out user alike, so nothing
  /// in the platform distinguishes them. The transition does: *was*
  /// authenticated, now is not.
  bool _wasAuthenticated = false;

  /// True while [signOut] is in flight, so the resulting emission is not
  /// mistaken for a session that lapsed on its own.
  bool _signingOut = false;

  /// Guards against re-entering the discard while its own sign-out emits.
  bool _discardingSession = false;

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
            _discardUnusableSession();
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
    state = AsyncData<AuthState>(_classify(next));
  }

  /// Distinguishes a session that lapsed from one that never existed.
  ///
  /// `AuthState.expired` cannot come from the platform: Volume 4 Chapter 4.7
  /// §3 has the SDK renew the ID token silently while the refresh token is
  /// valid, and when it stops being valid Firebase emits exactly the same
  /// `null` user it emits for a deliberate sign-out. The two are
  /// indistinguishable at the moment they arrive.
  ///
  /// They are distinguishable as a *transition*, which is what this reads: a
  /// user who was authenticated and is no longer, without having asked to be,
  /// has a session that ended on its own. That is what lets the login screen
  /// say why the person is looking at it again instead of showing a bare form.
  AuthState _classify(AuthState next) {
    if (next is AuthStateAuthenticated) {
      _wasAuthenticated = true;
      return next;
    }

    final bool lapsed = _wasAuthenticated && !_signingOut;
    _wasAuthenticated = false;
    return lapsed ? const AuthState.expired() : next;
  }

  Future<AuthState> _restore() async {
    try {
      final Session session = await _repository.restoreSession();
      final AuthState restored =
          AuthState.fromSession(session) ?? const AuthState.unauthenticated();
      // A restored session is the first thing that makes a later loss legible
      // as an expiry, so the transition is recorded here too and not only on
      // the stream.
      _wasAuthenticated = restored is AuthStateAuthenticated;
      return restored;
    } on AppException {
      // A restore that fails is not an error state to show: it means nobody is
      // signed in as far as this launch is concerned. Mission 2.5 owns
      // distinguishing a lapsed session, which is what AuthState.expired is
      // for.
      _discardUnusableSession();
      return const AuthState.unauthenticated();
    }
  }

  /// Signs out a persisted session the application cannot use.
  ///
  /// Firebase persists its own credential, so an account that authenticates
  /// but carries no `role` claim — one created outside the invite flow, or
  /// left behind by an earlier test — comes back on *every* cold start. The
  /// application would refuse it every time, and the person would have no way
  /// to reach Login and sign in as somebody else short of clearing the app's
  /// storage by hand.
  ///
  /// Refusing the session is correct; keeping it is not. Signing out ends the
  /// loop and leaves the next launch clean.
  ///
  /// Best-effort and deliberately unawaited: the caller is deciding what state
  /// to report right now, and the sign-out is housekeeping behind that
  /// decision. A failure here leaves the stale session in place, which is the
  /// situation that already existed.
  void _discardUnusableSession() {
    if (_discardingSession) {
      return;
    }
    _discardingSession = true;
    unawaited(
      _repository.signOut().catchError((Object _) {}).whenComplete(() {
        _discardingSession = false;
      }),
    );
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

  /// Creates an account against an organisation invite code.
  ///
  /// Same shape as the sign-in methods, and for the same reason: a rejected
  /// invite code is the outcome of one attempt, not a broken session.
  ///
  /// On success the repository has already created the account, redeemed the
  /// code, and refreshed the token so the new claims are readable — so the
  /// session stream reports an authenticated user and the route guard moves
  /// the person to their role's root without this method navigating.
  Future<Failure?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String inviteCode,
  }) {
    return _attempt(
      () => _repository.signUpWithEmailPassword(
        email: email,
        password: password,
        inviteCode: inviteCode,
      ),
    );
  }

  /// Creates an account from a Google identity and an invite code.
  Future<Failure?> signUpWithGoogle({required String inviteCode}) {
    return _attempt(() => _repository.signUpWithGoogle(inviteCode: inviteCode));
  }

  /// Signs out, ending the session.
  ///
  /// Flagged while in flight so the emission it causes is reported as
  /// `unauthenticated` rather than as `expired` — the user asked for this one.
  Future<Failure?> signOut() async {
    _signingOut = true;
    try {
      return await _attempt(_repository.signOut);
    } finally {
      _signingOut = false;
    }
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
