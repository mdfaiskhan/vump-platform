import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/features/auth/data/firebase_auth_error_mapper.dart';
import 'package:mobile/features/auth/data/firebase_functions_error_mapper.dart';
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
/// ## Sign-up works, and is still not reachable
///
/// [signUpWithEmailPassword] and [signUpWithGoogle] redeem a real invite code
/// against the Cloud Function ADR-036 describes. `SignupScreen` remains
/// routed and, since amendment A-056, linked from Login. The invite code is
/// optional; the role is Collector on every path.
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
    required this.logger,
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
  }) : _injectedAuth = firebaseAuth,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _injectedFunctions = functions;

  /// Destination for the one diagnostic this class writes — see `_discard`.
  final AppLogger logger;
  final fb.FirebaseAuth? _injectedAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions? _injectedFunctions;

  /// Resolved lazily, and pinned to the region the function is deployed to.
  ///
  /// A callable defaults to `us-central1`; ADR-036 deploys to `asia-south1`
  /// beside the Firestore database. A mismatch here fails at call time with a
  /// not-found that looks like a missing function rather than a wrong region.
  FirebaseFunctions get _functions =>
      _injectedFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-south1');

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
    String? inviteCode,
  }) {
    return _guard(
      description: 'create an account with an email address and password',
      action: () async {
        // The function validates the code and creates the account together,
        // server-side. Nothing is created here first, which is what closes
        // Mission 2.9's F1: a rejected code produces one indistinguishable
        // error whether or not the address was already registered, because no
        // account-creation attempt is made for the caller to observe.
        await _redeemInviteCode(
          inviteCode: inviteCode,
          email: email,
          password: password,
        );

        // The account now exists with its claims already set, so the first
        // token this sign-in receives carries them and no refresh is needed.
        final fb.UserCredential credential = await _firebaseAuth
            .signInWithEmailAndPassword(email: email, password: password);
        return _toUser(_requireUser(credential));
      },
    );
  }

  /// Creates an account from a Google identity and an invite code.
  ///
  /// **Deliberately still client-first, unlike the email/password path.**
  /// There is no password to hand the server, and
  /// `signInWithCredential` creates the Firebase account as a side effect of
  /// the first federated sign-in — the account exists before any code of ours
  /// runs.
  ///
  /// Mission 2.9's F1 does not reach here, for a structural reason. The
  /// enumeration oracle existed because email/password sign-up let a caller
  /// *assert* an arbitrary address; Google sign-up requires *authenticating
  /// as* the identity, so a probe reveals only accounts the caller already
  /// controls. See ADR-036's Mission 2.10 amendment.
  ///
  /// The compensating delete therefore stays on this path, where it still has
  /// something to compensate for.
  @override
  Future<User> signUpWithGoogle({String? inviteCode}) {
    return _guard(
      description: 'create an account with Google',
      action: () async {
        final fb.UserCredential credential = await _authenticateWithGoogle();
        return _provisionFederated(_requireUser(credential), inviteCode);
      },
    );
  }

  /// Redeems a code for an account Google has just created, or undoes it.
  ///
  /// Only the federated path reaches this. The email/password path no longer
  /// creates anything before validating, so it has nothing to undo.
  ///
  /// ## The token must be refreshed before the claims are readable
  ///
  /// `setCustomUserClaims` writes on the server. The ID token this device is
  /// holding was minted before that write and does not carry the new claims,
  /// so `_toUser` would find no `role` and reject the account it just
  /// provisioned. Forcing a refresh is what closes that window.
  Future<User> _provisionFederated(fb.User user, String? inviteCode) async {
    try {
      await _redeemInviteCode(
        inviteCode: inviteCode,
        email: user.email ?? '',
        password: null,
      );
    } on AppException {
      await _discard(user);
      rethrow;
    }

    await user.getIdToken(true);
    return _toUser(user);
  }

  /// Deletes an account whose provisioning failed.
  ///
  /// A best-effort compensation, and its own failure is reported rather than
  /// swallowed — `empty_catches` is an analyzer error under ADR-021 for
  /// exactly this shape, and a leftover account is something support needs to
  /// know about. The redemption failure is still what reaches the caller: it
  /// is the one they can act on.
  Future<void> _discard(fb.User user) async {
    try {
      await user.delete();
    } on Object catch (error, stackTrace) {
      logger.error(
        'Could not remove the account created for a sign-up whose invite '
        'code was rejected. It exists with no organisation and no role, and '
        'the address it holds cannot be reused until it is deleted.',
        error: error,
        stackTrace: stackTrace,
      );
    }
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

  /// Validates an invite code and provisions the account behind it.
  ///
  /// **TEMPORARY — calls the Cloud Function ADR-036 retires at Mission 6/7.**
  ///
  /// [password] is null on the federated path, where Google has already
  /// created the account and the function only redeems and sets claims. On the
  /// email/password path it is present, and the function creates the account
  /// itself after the code checks out — the ordering that closes F1.
  ///
  /// The password is sent once, over HTTPS, to a function that passes it
  /// straight to `createUser`. It is never logged here or there.
  ///
  /// Throws an `AuthenticationException` carrying
  /// `AUTH_INVITE_CODE_INVALID` or `AUTH_INVITE_CODE_EXPIRED`. A registered
  /// address is reported as the former, not as its own condition — see
  /// ADR-036.
  Future<void> _redeemInviteCode({
    required String? inviteCode,
    required String email,
    required String? password,
  }) async {
    try {
      // Built imperatively rather than as a literal with null-aware elements.
      // `?value` is recent Dart syntax, and the code-generation chain runs
      // analyzer 5.13.0 — capped below 6.0.0 by `isar_generator` (A-048) —
      // which cannot parse it. `flutter analyze` accepts it and build_runner
      // does not, so the literal form breaks codegen while looking clean.
      final Map<String, Object?> payload = <String, Object?>{'email': email};
      // Omitted when absent rather than sent empty or null: the function reads
      // a missing code as "the default organisation" (A-056) and a missing
      // password as "the account already exists" (the federated path).
      if (inviteCode != null) {
        payload['code'] = inviteCode;
      }
      if (password != null) {
        payload['password'] = password;
      }

      await _functions.httpsCallable('redeemInviteCode').call<Object?>(payload);
    } on FirebaseFunctionsException catch (error, stackTrace) {
      throw FirebaseFunctionsErrorMapper.toAuthenticationException(
        error,
        stackTrace,
        description: 'redeem the invite code',
      );
    }
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
