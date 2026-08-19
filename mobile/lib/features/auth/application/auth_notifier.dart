import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
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
    // ONE subscription, and it is the only thing that resolves a session.
    //
    // This used to be a subscription PLUS a `restoreSession()` call, and both
    // reached `AuthRepositoryImpl._toUser` — so every cold start for an
    // already-signed-in Collector performed `POST /v1/auth/verify` twice,
    // concurrently. Gap 11 in the Mission 6 register; A-177 records the fix.
    //
    // The second call bought nothing. The comment that used to sit here said
    // awaiting the stream "would stall build()" — but the restore stalls it by
    // exactly as much, because both wait on the same token exchange, and the
    // stream already yields `Session.unknown()` first so the UI has its
    // AsyncLoading either way.
    //
    // Resolving the first session through THIS subscription rather than a
    // second `sessionChanges` read matters: the getter is a stream that
    // subscribes to Firebase and maps each event through `_toUser`, so reading
    // it twice would reintroduce the duplicate exchange in a new place.
    final Completer<AuthState> first = Completer<AuthState>();

    final StreamSubscription<Session> subscription = _repository.sessionChanges
        .listen(
          (Session session) {
            _onSession(session);
            // `Session.unknown` carries no AuthState — it is "not yet
            // determined" and must not complete the first-session future.
            final AuthState? resolved = AuthState.fromSession(session);
            if (resolved != null && !first.isCompleted) {
              first.complete(_stateOrUnauthenticated());
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            // Order matters, and it is the original order restored. The
            // discard signs out, the fake and the real repository both emit on
            // sign-out, and that emission runs `_onSession` — so discarding
            // BEFORE writing the state lets the sign-out overwrite the error
            // that caused it, and the notifier ends up reporting a tidy
            // `unauthenticated` for a session it could not read at all.
            //
            // Before the first session resolves there is no state to
            // overwrite: the launch simply has nobody signed in, which is what
            // `_restore` decided on the same condition and why an error here
            // is not surfaced as one. A first-run user who has never signed in
            // must not meet an error banner.
            if (first.isCompleted) {
              state = AsyncError<AuthState>(error, stackTrace);
            } else {
              first.complete(const AuthState.unauthenticated());
            }

            // F5, A-178. Only a session that is genuinely unusable is
            // discarded. A 502 from `POST /v1/auth/verify` used to sign the
            // Collector out — reproduced on CPH2707, where Aurora's resume from
            // MinCapacity 0 outran the Lambda's 15s timeout (gap 9) and the
            // resulting NetworkException travelled this path.
            if (_isUnusableSession(error)) {
              _discardUnusableSession();
            }
          },
        );
    ref.onDispose(subscription.cancel);

    return first.future;
  }

  /// The state `_onSession` has just written, which has already been through
  /// [_classify] — so the expiry bookkeeping is applied exactly once.
  AuthState _stateOrUnauthenticated() {
    return state.valueOrNull ?? const AuthState.unauthenticated();
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

  /// Whether [error] means the persisted session can never work, as opposed to
  /// not working right now.
  ///
  /// **The distinction is real rather than a reluctance to sign people out**,
  /// and it rests on something the platform already guarantees: a revoked
  /// refresh token or a deleted account does NOT arrive here at all. Firebase
  /// emits a null user for those, exactly as it does for a deliberate sign-out,
  /// which `_classify` turns into `unauthenticated` or `expired`. Nothing that
  /// reaches this method is a revocation, so narrowing it masks no real
  /// invalidity.
  ///
  /// What does reach it:
  ///
  /// - `AuthenticationException(authUnauthenticated)` — the account signs in
  ///   but carries no usable `role` claim, or the backend has no organisation
  ///   for it. Permanent until somebody provisions it, and it comes back on
  ///   every cold start, so the session must be cleared or the person can never
  ///   reach Login to sign in as somebody else. This is the case the discard
  ///   was written for.
  /// - `AuthenticationException(authAccountDisabled)` — likewise permanent.
  /// - `NetworkException(*)` — a 502, a timeout, no connectivity. **Transient,
  ///   and signing out is the one response that makes it worse**: the
  ///   credential is destroyed, so recovery needs the person's password rather
  ///   than a working backend.
  /// - `AuthenticationException(unknown)` — Firebase failed to initialise
  ///   (ADR-017). A local fault, and `signOut` could not succeed either.
  static bool _isUnusableSession(Object error) {
    return error is AppException &&
        const <ErrorCode>{
          ErrorCode.authUnauthenticated,
          ErrorCode.authAccountDisabled,
        }.contains(error.errorCode);
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
    String? inviteCode,
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
  Future<Failure?> signUpWithGoogle({String? inviteCode}) {
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
