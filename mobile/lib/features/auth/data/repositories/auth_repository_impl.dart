import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/vump_api.dart';
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
    required this.backend,
  }) : _injectedAuth = firebaseAuth,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Destination for the one diagnostic this class writes — see `_discard`.
  final AppLogger logger;

  /// The Vump backend, for Chapter 4.7 §1 step 2's token exchange.
  ///
  /// **Required.** It was nullable until Mission 7.2, with the null case
  /// documented as "the test path": when absent, `org_id` fell back to the
  /// Firebase claim — the pre-ADR-048 behaviour that ADR-048 retired, because
  /// *"a claim written once goes stale the moment an account moves
  /// organisation"*.
  ///
  /// The old comment argued the fallback was unreachable on a device because
  /// `main.dart` always supplies a backend. That was true, and it was a
  /// convention rather than a guarantee — the same shape as Mission 6.5's
  /// `authTokenSourceProvider` defect, which was also correct in isolation and
  /// wrong at the composition root. A type is a guarantee; a convention is a
  /// thing to be got right again every time somebody adds a call site.
  ///
  /// Tests pass a fake `VumpApi` instead of omitting it, which also makes the
  /// exchange observable — see `_FakeVumpApi` in the auth tests, and A-179.
  final VumpApi backend;

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
  /// **`POST /v1/auth/redeem`, since Mission 7.6.** This called a Firebase
  /// Cloud Function until Phase 5; ADR-036 always described that as temporary,
  /// and the reason it existed — that running the Admin SDK outside Google
  /// meant holding a service-account key able to grant `admin` on any
  /// organisation — was removed rather than accepted. The Lambda reaches
  /// Firebase through Workload Identity Federation and no key exists anywhere.
  ///
  /// ## The route is unauthenticated, and that is not a gap
  ///
  /// Its caller has no account — creating one is the point — so there is no
  /// token to verify and no `users` row to look up. It is one of exactly two
  /// routes exempt from the REQUEST authorizer, named in an allowlist that a
  /// Terraform `check` asserts (ADR-048's Mission 7.6 amendment).
  ///
  /// `AuthInterceptor` attaches a bearer token when one exists and proceeds
  /// without one otherwise. On the email/password path nobody is signed in, so
  /// nothing is attached. On the federated path Google has already signed the
  /// user in, so a token *is* attached and API Gateway ignores it — harmless,
  /// and worth knowing before someone reads the header as meaningful.
  ///
  /// ## No error mapping happens here any more
  ///
  /// `FirebaseFunctionsErrorMapper` existed because a callable reports failures
  /// as a fixed gRPC status set that says nothing about this application's
  /// taxonomy, so the real code had to be dug out of `details.errorCode`. A
  /// route answers with the Chapter 4.6 envelope and `ErrorInterceptor` already
  /// maps it. The mapper was deleted rather than ported, exactly as its own
  /// header said it would be.
  ///
  /// **One code covers every rejection**: `AUTH_INVITE_CODE_INVALID`, whether
  /// the code is missing, expired, exhausted, or the address is already
  /// registered. `AUTH_INVITE_CODE_EXPIRED` no longer exists — distinguishing
  /// expiry told an unauthenticated caller which guesses named a real code,
  /// which is the enumeration oracle Mission 2.9's F1 removed from the
  /// account-creation path. Same reasoning, second place. See A-223's mission.
  ///
  /// ## [password] is null on the federated path, and the server rejects that
  ///
  /// **Known pre-existing defect, carried forward deliberately.** The server
  /// requires an email AND a password and always calls `createUser`; the
  /// federated path has no password to send, because Google created the
  /// account before any of this ran. That request is refused as a validation
  /// failure — and was refused by the Cloud Function too, on the same
  /// condition, so Mission 7.6 neither introduced this nor fixed it.
  ///
  /// Fixing it needs a server capability that provisions claims for an account
  /// that already exists, which is new behaviour and a new authorization
  /// question rather than a port. Out of scope for a retirement mission and
  /// recorded as its own amendment.
  ///
  /// The password is sent once, over HTTPS, to a route that passes it straight
  /// to `createUser`. It is never logged here or there.
  Future<void> _redeemInviteCode({
    required String? inviteCode,
    required String email,
    required String? password,
  }) async {
    // Built imperatively rather than as a literal with null-aware elements.
    // `?value` is recent Dart syntax, and the code-generation chain runs
    // analyzer 5.13.0 — capped below 6.0.0 by `isar_generator` (A-048) —
    // which cannot parse it. `flutter analyze` accepts it and build_runner
    // does not, so the literal form breaks codegen while looking clean.
    final Map<String, Object?> payload = <String, Object?>{'email': email};
    // Omitted when absent rather than sent empty or null: the server reads a
    // missing code as "the default organisation" (A-056) and validates a
    // missing password as a bad request.
    if (inviteCode != null) {
      payload['code'] = inviteCode;
    }
    if (password != null) {
      payload['password'] = password;
    }

    // The 201 body carries `{uid, orgId}` and nothing here reads it: the
    // claims are already on the account, so the sign-in that follows receives
    // a token that carries them. `VumpApi` unwraps the envelope, and a
    // failure arrives as an `AppException` that `ErrorInterceptor` has already
    // given the right code.
    await backend.post(
      '/auth/redeem',
      what: 'redeem the invite code',
      body: payload,
    );
  }

  /// Builds the domain [User] from Firebase's identity and the backend's
  /// session context.
  ///
  /// **Neither `role` nor `orgId` comes from the ID token any more.** Both are
  /// read from `POST /v1/auth/verify`, which answers from the `users` table.
  ///
  /// Volume 4 Chapter 4.7 §2 sets the role as a Firebase custom claim *"at
  /// account provisioning time… not read from a request body — a client can
  /// never claim its own role"*, and this file read that claim until Mission
  /// 7.8. The claim is still what provisioning writes and still what the client
  /// cannot forge; what changed is that it is no longer the client's SOURCE.
  ///
  /// ADR-048 made this argument for `org_id` and did not extend it to `role`:
  /// *"a claim written once goes stale the moment an account moves
  /// organisation"*. A role is written once at provisioning too, and the
  /// authorizer has always resolved `Caller.role` from the `users` table —
  /// documented there as *"Authoritative role from the users table, not the
  /// token claim"*. So the client believed the claim while the server believed
  /// the table, and a role changed in one and not the other put the two out of
  /// step until the next token refresh. Same argument, second field.
  ///
  /// Firebase still supplies what only Firebase knows: `uid`, `email`,
  /// `emailVerified`, `displayName`.
  Future<User> _toUser(fb.User user) async {
    final _VerifiedSession session = await _resolveSession();

    return User(
      uid: user.uid,
      // `users.id`, NOT the Firebase uid — A-206. Every backend row that
      // references a person holds this one, and the metadata route refuses a
      // document whose `collector_id` is anything else.
      backendUserId: session.userId,
      email: user.email ?? '',
      // **From the backend, not from the claim** — see `_fetchSession`.
      role: session.role,
      orgId: session.orgId,
      emailVerified: user.emailVerified,
      displayName: user.displayName,
    );
  }

  /// The organisation this account belongs to, from the backend — ADR-048.
  ///
  /// Chapter 4.7 §1 step 2 has the app attach its Firebase ID token to a
  /// backend call; `POST /v1/auth/verify` exchanges it for the session context
  /// and, on a first login, creates the `users` row that every other route's
  /// authorizer requires. The token is attached by `AuthInterceptor`, so this
  /// passes no credential itself.
  ///
  /// **`userId` comes from the response too, and it is not the Firebase uid.**
  /// `POST /v1/auth/verify` has always returned `{ userId, orgId, role }` and
  /// this method read `orgId` and discarded the rest. Mission 7.4 step 3 then
  /// wired `identity.collector_id` to `fb.User.uid`, and the metadata route
  /// joins `sessions.collector_id` — a `users.id` — and refuses a document that
  /// disagrees. Every metadata POST would have been refused. A-206.
  ///
  /// **`org_id` comes from the response, not from the claim.** ADR-048 retires
  /// A-159's design in which the claim was authoritative: Chapter 4.7 §2 says
  /// the `users` table is the source *"if the claim and the table ever
  /// disagree"*, and a claim written once goes stale the moment an account
  /// moves organisation. `role` is unaffected and still comes from the claim,
  /// which Chapter 4.7 §2 specifies.
  ///
  /// There is no claim fallback. It existed while [backend] was nullable and
  /// was removed in Mission 7.2 — see the field's documentation.
  /// Coalesces overlapping resolutions onto ONE request — F6, A-180.
  ///
  /// A sign-in performs the exchange twice, ~4ms apart, and both succeed:
  ///
  ///     20:49:48.523  → POST /auth/verify
  ///     20:49:48.527  → POST /auth/verify
  ///
  /// `signInWithEmailPassword` calls [_toUser] to satisfy its `Future<User>`
  /// return type, and Firebase then emits that user on `authStateChanges`,
  /// so `sessionChanges` calls [_toUser] again. Same redundant exchange as
  /// gap 11, different cause: that was two paths inside `AuthNotifier.build`
  /// (A-177); this is the sign-in method and the stream reacting to it.
  ///
  /// **Deleting the sign-in call would have been smaller and wrong.** The
  /// returned `User` is genuinely unused — `AuthNotifier._attempt` takes a
  /// `Future<void> Function()` and discards it — but [_toUser] also VALIDATES,
  /// and on the sign-in path a `Failure` is what puts "this account is not
  /// provisioned" on the login form. Move that validation to the stream and it
  /// arrives as an `authUnauthenticated` error, which A-178 correctly treats as
  /// an unusable session and signs out — silently, with no message. Coalescing
  /// keeps every semantic and removes only the duplicate request.
  ///
  /// This shares the in-flight future only, never a completed result, so there
  /// is no cache to go stale: once the request settles the field is cleared and
  /// the next resolution is a fresh call. The window is the overlap itself. It
  /// is the same single-flight `AuthInterceptor._refreshInFlight` already uses
  /// for concurrent 401s.
  Future<_VerifiedSession>? _sessionInFlight;

  Future<_VerifiedSession> _resolveSession() {
    return _sessionInFlight ??= _fetchSession().whenComplete(() {
      _sessionInFlight = null;
    });
  }

  Future<_VerifiedSession> _fetchSession() async {
    final Map<String, Object?> data = await backend.post(
      '/auth/verify',
      what: 'Establishing your session',
    );
    final Object? userId = data['userId'];
    final Object? orgId = data['orgId'];
    final Role? role = switch (data['role']) {
      'collector' => Role.collector,
      'admin' => Role.admin,
      _ => null,
    };

    // All three or none. A response carrying some and not others means the
    // route's contract changed, and continuing with a blank would put an empty
    // `collector_id` on every chunk this session records — the substitution
    // A-068's Guard 1 exists to refuse, arriving from the other end.
    //
    // An unrecognised `role` is refused rather than defaulted, for `org.ts`'s
    // reason on the server side: guessing `collector` would grant an identity
    // the backend never issued, and guessing `admin` is worse.
    if (userId is String &&
        userId.isNotEmpty &&
        orgId is String &&
        orgId.isNotEmpty &&
        role != null) {
      return _VerifiedSession(userId: userId, orgId: orgId, role: role);
    }
    throw const AuthenticationException(
      errorCode: ErrorCode.authUnauthenticated,
      message:
          'The backend did not return a user, an organisation and a role for '
          'this account, so it has not been provisioned for this application.',
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

/// What `POST /v1/auth/verify` establishes about the caller.
///
/// Two ids, kept together because they arrive together and because separating
/// them is how A-206 happened: the Firebase uid and `users.id` are both
/// non-empty strings on the same account, and nothing but a name distinguishes
/// them at a call site.
class _VerifiedSession {
  const _VerifiedSession({
    required this.userId,
    required this.orgId,
    required this.role,
  });

  /// `users.id` — the backend's identifier, never the Firebase uid.
  final String userId;

  /// `users.org_id`, the organisation BR-20 scopes every query by.
  final String orgId;

  /// `users.role`, which the authorizer treats as authoritative.
  final Role role;
}
