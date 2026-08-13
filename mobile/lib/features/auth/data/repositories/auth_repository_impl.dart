import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/data/firebase_auth_error_mapper.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Firebase-backed implementation of [AuthRepository].
///
/// **The only file in the application that imports `firebase_auth` or
/// `google_sign_in`.** The `Architecture boundaries` CI job enforces it, on the
/// same footing as `dio` in `core/network/` and `isar` in `core/database/`
/// (ADR-022 §2.3). Firebase Authentication is the provider Volume 4 Chapter 4.1
/// confirms and Chapter 4.7 designs the sign-in flow against.
///
/// ## Error boundary
///
/// No `FirebaseAuthException` and no `GoogleSignInException` escapes this
/// class. Every path converts to `AuthenticationException` through
/// [FirebaseAuthErrorMapper], which is where the code mapping lives and is
/// documented — the guarantee `DioClient` makes for `DioException`.
///
/// ## Where Firebase initialisation is assumed
///
/// This class resolves the default app through the SDK's own registry, per
/// ADR-010: `FirebaseAuth.instance` requires `Firebase.initializeApp` to have
/// completed. ADR-010 requires a product provider to depend on
/// `firebaseAppProvider` so that ordering is a dependency rather than an
/// assumption. **No such provider exists yet** — provider wiring belongs to
/// Mission 2.3 (`application/`), which this mission may not touch. Until then a
/// caller must construct this class only after `firebaseAppProvider` resolves.
///
/// ## What is deliberately not implemented
///
/// [signUpWithEmailPassword] and [signUpWithGoogle] are blocked, not omitted.
/// See [_redeemInviteCode].
class AuthRepositoryImpl implements AuthRepository {
  /// Creates a repository over [firebaseAuth] and [googleSignIn].
  ///
  /// Both default to the SDK singletons. The parameters exist for
  /// substitutability, the rule ADR-008 applies to `SecureStorageService`.
  ///
  /// **The `googleSignIn` parameter is weaker than it looks.** `GoogleSignIn`
  /// has only a private constructor in `google_sign_in 7.2.0`, so it cannot be
  /// subclassed and no fake can be passed. Substituting it in a test means
  /// replacing `GoogleSignInPlatform.instance` instead. The parameter is kept
  /// because the boundary belongs in the signature regardless of what today's
  /// package permits.
  AuthRepositoryImpl({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _injectedAuth = firebaseAuth,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth? _injectedAuth;
  final GoogleSignIn _googleSignIn;

  /// Resolved on each use rather than in the constructor.
  ///
  /// `FirebaseAuth.instance` calls `Firebase.app()`, which throws
  /// `FirebaseException(core/no-app)` when the platform never initialised — a
  /// state ADR-017 tolerates in development. Resolving it in the initializer
  /// list put that throw outside [_guard], so constructing this class leaked a
  /// raw `FirebaseException` and broke the very guarantee ADR-034 states.
  /// Every read here happens inside a guarded call. See ADR-035.
  fb.FirebaseAuth get _firebaseAuth =>
      _injectedAuth ?? fb.FirebaseAuth.instance;

  /// Holds the in-flight `initialize` call so concurrent callers share one.
  ///
  /// `google_sign_in 7.x` requires `initialize` to be called *"exactly once,
  /// and wait for its future to complete, before calling any other methods"* —
  /// calling it twice is documented as undefined behaviour. Holding the future
  /// rather than a boolean is the same pattern ADR-009 requires of
  /// `DatabaseService` and ADR-010 of `FirebaseInitializer`: two sign-in taps
  /// in quick succession share one initialisation instead of racing.
  Future<void>? _googleInitialization;

  /// The claim carrying the user's role, per Volume 4 Chapter 4.7 §2.
  static const String _roleClaim = 'role';

  /// The claim carrying the user's organisation.
  ///
  /// Volume 4 Chapter 4.7 §2 names only `role` as a custom claim and sources
  /// `org_id` from the backend's `users` table. Carrying it in the token is a
  /// decision taken by this mission and recorded in ADR-034 and amendment
  /// A-052. The snake_case spelling matches Volume 4's own naming.
  static const String _orgIdClaim = 'org_id';

  @override
  Stream<Session> get sessionChanges async* {
    // Firebase's stream has no "not yet known" event: it emits null for a
    // signed-out user and a User for a signed-in one, and at cold start the
    // first emission has not happened yet. Session.unknown() is originated
    // here rather than mapped from anything, so a subscriber never sees
    // unauthenticated before the restore has actually been attempted —
    // which is what would flash the login screen at an already-signed-in
    // Collector on every launch.
    yield const Session.unknown();

    // Subscribing is itself a Firebase call: resolving the SDK throws
    // `core/no-app` when startup tolerated an initialisation failure
    // (ADR-017). Guarded so the stream errors with an AuthenticationException
    // rather than a raw FirebaseException — a stream error is as much a
    // boundary crossing as a thrown one. See ADR-035.
    final Stream<fb.User?> changes = await _guard(
      description: 'observe the session',
      action: () async => _firebaseAuth.authStateChanges(),
    );

    await for (final fb.User? user in changes) {
      if (user == null) {
        yield const Session.unauthenticated();
      } else {
        yield Session.authenticated(await _toUser(user));
      }
    }
  }

  @override
  Future<Session> restoreSession() {
    return _guard(
      description: 'restore the previous session',
      action: () async {
        final fb.User? current = _firebaseAuth.currentUser;
        if (current == null) {
          return const Session.unauthenticated();
        }
        return Session.authenticated(await _toUser(current));
      },
    );
  }

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _guard(
      description: 'sign in with an email address and password',
      action: () async {
        final fb.UserCredential credential = await _firebaseAuth
            .signInWithEmailAndPassword(email: email, password: password);
        return _toUser(_requireUser(credential));
      },
    );
  }

  @override
  Future<User> signInWithGoogle() {
    return _guard(
      description: 'sign in with Google',
      action: () async {
        final fb.UserCredential credential = await _authenticateWithGoogle();
        return _toUser(_requireUser(credential));
      },
    );
  }

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    // Redemption first, deliberately. Creating the Firebase account before the
    // invite code is known good would leave an orphaned account behind every
    // rejected sign-up, and nothing in this codebase deletes it.
    await _redeemInviteCode(inviteCode);

    return _guard(
      description: 'create an account with an email address and password',
      action: () async {
        final fb.UserCredential credential = await _firebaseAuth
            .createUserWithEmailAndPassword(email: email, password: password);
        return _toUser(_requireUser(credential));
      },
    );
  }

  @override
  Future<User> signUpWithGoogle({required String inviteCode}) async {
    await _redeemInviteCode(inviteCode);

    return _guard(
      description: 'create an account with Google',
      action: () async {
        final fb.UserCredential credential = await _authenticateWithGoogle();
        return _toUser(_requireUser(credential));
      },
    );
  }

  @override
  Future<void> signOut() {
    return _guard(
      description: 'sign out',
      action: () async {
        // Both, and in this order. Signing out of Firebase alone leaves the
        // Google account selected, so the next sign-in silently reuses it
        // instead of showing the picker — which reads as "sign out did not
        // work" on a shared device.
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
      },
    );
  }

  /// Runs the native Google picker and exchanges the result with Firebase.
  Future<fb.UserCredential> _authenticateWithGoogle() async {
    _googleInitialization ??= _googleSignIn.initialize();
    await _googleInitialization;

    final GoogleSignInAccount account = await _googleSignIn.authenticate();

    // `google_sign_in 7.x` returns only the ID token from authentication; an
    // access token is a separate authorization concern now. Firebase accepts
    // the ID token alone, and asking for an access token would prompt for
    // scopes this flow does not need.
    final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Validates and consumes an organisation invite code.
  ///
  /// **BLOCKED — there is nothing to validate against, and this throws.**
  ///
  /// Redeeming a code requires a server that owns the code's existence, its
  /// expiry and its remaining uses; none of that can be decided on a device
  /// the person holding the code controls. `backend/` is empty (ADR-015), and
  /// Volume 4 Chapter 4.6 specifies exactly two auth endpoints —
  /// `POST /v1/auth/verify` and `GET /v1/users/me` — neither of which redeems
  /// anything.
  ///
  /// It throws rather than returning, and it throws an `UnimplementedError`
  /// rather than an `AuthenticationException`, for one reason: an
  /// `AuthenticationException` would be caught by `application/` and rendered
  /// to a user as "that code is not valid", which is a lie about a code nobody
  /// checked. An `Error` is not part of the failure taxonomy and is not
  /// handled — it stops the program, which is the correct response to a path
  /// that was never built.
  ///
  /// A no-op that returned normally would be worse than either: it would open
  /// self-service registration to anyone who can type a string.
  Future<void> _redeemInviteCode(String inviteCode) {
    throw UnimplementedError(
      'Organisation invite codes cannot be redeemed: no endpoint exists to '
      'validate one against. Volume 4 Chapter 4.6 defines no redemption '
      'route and backend/ is empty (ADR-015). See ADR-034 and amendment '
      'A-051. Sign-up must stay unreachable in the UI until this is built.',
    );
  }

  /// Reads the domain [User] out of the ID token's custom claims.
  ///
  /// Volume 4 Chapter 4.7 §2 sets the role as a Firebase custom claim *"at
  /// account provisioning time… not read from a request body — a client can
  /// never claim its own role"*. That property is what makes this read safe:
  /// the token is signed by Firebase, so the app is reporting a claim rather
  /// than choosing one.
  ///
  /// Throws when a claim is absent or unrecognised, rather than defaulting.
  /// A missing role is an unprovisioned account, and guessing `collector`
  /// would grant an identity the provisioning step never issued.
  Future<User> _toUser(fb.User user) async {
    final fb.IdTokenResult token = await user.getIdTokenResult();
    final Map<String, dynamic> claims =
        token.claims ?? const <String, dynamic>{};

    final Role role = switch (claims[_roleClaim]) {
      'collector' => Role.collector,
      'admin' => Role.admin,
      _ => throw const AuthenticationException(
        errorCode: ErrorCode.authUnauthenticated,
        message:
            'The signed-in account carries no usable "$_roleClaim" claim, so '
            'it has not been provisioned for this application.',
      ),
    };

    final Object? orgId = claims[_orgIdClaim];
    if (orgId is! String || orgId.isEmpty) {
      throw const AuthenticationException(
        errorCode: ErrorCode.authUnauthenticated,
        message:
            'The signed-in account carries no "$_orgIdClaim" claim, so it '
            'belongs to no organisation.',
      );
    }

    return User(
      uid: user.uid,
      email: user.email ?? '',
      role: role,
      orgId: orgId,
      emailVerified: user.emailVerified,
      displayName: user.displayName,
    );
  }

  /// Unwraps the `User` from a credential, which the SDK types as nullable.
  ///
  /// It is non-null on every successful path; the null case is a contract
  /// violation by the SDK, not a failure mode a caller can act on.
  fb.User _requireUser(fb.UserCredential credential) {
    final fb.User? user = credential.user;
    if (user == null) {
      throw const AuthenticationException(
        errorCode: ErrorCode.unknown,
        message: 'Firebase returned a credential carrying no user.',
      );
    }
    return user;
  }

  /// Runs [action], converting any failure into an `AuthenticationException`.
  ///
  /// [description] names the attempted operation for the log. It never carries
  /// an email address, a password or a token — `AuthenticationException` holds
  /// no credential, and an exception message is a log line waiting to happen.
  Future<T> _guard<T>({
    required String description,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on AuthenticationException {
      // Already in the taxonomy — thrown by _toUser or _requireUser. Rethrow
      // rather than wrap, per error-handling.md §26 rule 2.
      rethrow;
    } on fb.FirebaseAuthException catch (error, stackTrace) {
      throw FirebaseAuthErrorMapper.toAuthenticationException(
        error,
        stackTrace,
        description: description,
      );
    } on fb.FirebaseException catch (error, stackTrace) {
      // The platform rather than the product, and it must come after the
      // FirebaseAuthException clause above because that type extends this one.
      // `core/no-app` and `core/not-initialized` both land here and both mean
      // startup tolerated a Firebase failure (ADR-017) and something now needs
      // it. Named so the message says Firebase instead of reporting an
      // unclassified authentication failure. See ADR-035.
      throw AuthenticationException(
        errorCode: ErrorCode.unknown,
        message:
            'Firebase is not initialised, so the application could not '
            '$description (firebase code: ${error.code}).',
        cause: error,
        stackTrace: stackTrace,
      );
    } on GoogleSignInException catch (error, stackTrace) {
      throw AuthenticationException(
        errorCode: switch (error.code) {
          // Not a failure. The person changed their mind, and reporting that
          // as an error would put a red banner under a deliberate action.
          GoogleSignInExceptionCode.canceled => ErrorCode.authSignInCancelled,
          GoogleSignInExceptionCode.interrupted ||
          GoogleSignInExceptionCode.uiUnavailable =>
            ErrorCode.networkUnavailable,
          _ => ErrorCode.unknown,
        },
        message:
            'Google Sign-In could not $description '
            '(google code: ${error.code.name}).',
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      // Required, not defensive. error-handling.md §7 makes the catch-all the
      // reason `avoid_catches_without_on_clauses` is excluded from the lint
      // set: a boundary that caught only what it had thought of would let the
      // rest through untranslated.
      throw AuthenticationException(
        errorCode: ErrorCode.unknown,
        message: 'Authentication could not $description.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
