import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Hand-rolled fakes for the Google and Cloud Functions surfaces.
///
/// `mocktail` is not a dependency — amendment A-028 declined it, and
/// testing-standards.md §8 asks for fakes rather than mocks regardless. These
/// classes use `implements` plus `noSuchMethod` because every type below has a
/// private constructor and cannot be extended.
///
/// **Each fake models behaviour, not canned values.** `FakeGoogleSignIn` has
/// an outcome it plays out, so a test can ask for a cancellation and get the
/// same `GoogleSignInException` the SDK raises rather than a generic error —
/// a fake that could not tell "the person dismissed the sheet" from "the SDK
/// failed" would prove nothing about the mapping that distinguishes them.
///
/// `GoogleSignInAuthentication` and `GoogleSignInException` are **not** faked.
/// Both have public constructors, so the real types are used; a fake standing
/// in for a class the test can simply build would only add a way to diverge.

/// What a Google sign-in attempt does when it is run.
enum GoogleOutcome {
  /// Returns an account carrying an ID token.
  succeeds,

  /// The person dismissed the account picker. Not a failure — the SDK reports
  /// it with its own code, and Mission 2.2's mapper turns that into
  /// `AUTH_SIGN_IN_CANCELLED`.
  cancelled,

  /// The SDK itself failed — no network, a misconfigured client.
  errors,

  /// Signs in, but the account carries no ID token. Firebase cannot build a
  /// credential from it, so this exercises the path past `authenticate`.
  succeedsWithoutToken,
}

/// A `GoogleSignIn` that plays out one [GoogleOutcome].
class FakeGoogleSignIn implements GoogleSignIn {
  FakeGoogleSignIn({this.outcome = GoogleOutcome.succeeds});

  final GoogleOutcome outcome;

  /// How many times `initialize` actually ran.
  ///
  /// The package documents initialisation as "exactly once, and wait for its
  /// future to complete, before calling any other methods", and undefined
  /// behaviour if called twice. `AuthRepositoryImpl` holds the in-flight
  /// future to guarantee that; this counter is how a test can see it.
  int initializeCalls = 0;

  /// How many times the picker was shown.
  int authenticateCalls = 0;

  /// How many times the repository signed out of Google.
  int signOutCalls = 0;

  /// True once `initialize` has completed, so [authenticate] can assert
  /// ordering rather than silently tolerating a violation.
  bool _initialized = false;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls += 1;
    // A real await, so two concurrent callers can actually overlap and a
    // missing single-flight guard would show up as initializeCalls == 2.
    await Future<void>.delayed(Duration.zero);
    _initialized = true;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticateCalls += 1;

    if (!_initialized) {
      // Modelling the package's contract rather than ignoring it. If the
      // repository ever stops awaiting initialize, the test fails here with a
      // message that says so, instead of passing by luck.
      throw StateError(
        'authenticate() was called before initialize() completed, which '
        'google_sign_in documents as undefined behaviour.',
      );
    }

    return switch (outcome) {
      GoogleOutcome.succeeds => FakeGoogleSignInAccount(idToken: 'google-id'),
      GoogleOutcome.succeedsWithoutToken => FakeGoogleSignInAccount(),
      GoogleOutcome.cancelled => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'The user dismissed the picker.',
      ),
      GoogleOutcome.errors => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'The underlying auth SDK is unavailable.',
      ),
    };
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An account whose `authentication` carries the token — or does not.
///
/// `avoid_implementing_value_types` fires on any class implementing a type
/// that defines `==`, and `GoogleSignInAccount` does. The rule's concern is an
/// implementer that silently inherits identity equality; this one defines `==`
/// and `hashCode` over the same field, so the concern is answered rather than
/// waved away. `extends` is not available — the constructor is private — so
/// `implements` is the only way to fake it at all.
// ignore: avoid_implementing_value_types
class FakeGoogleSignInAccount implements GoogleSignInAccount {
  FakeGoogleSignInAccount({this.idToken});

  final String? idToken;

  @override
  String get id => 'google-user-1';

  @override
  String get email => 'someone@example.com';

  @override
  String? get displayName => 'Someone';

  @override
  GoogleSignInAuthentication get authentication =>
      // The real type: it has a public const constructor, so there is nothing
      // for a fake to add.
      GoogleSignInAuthentication(idToken: idToken);

  // GoogleSignInAccount is a value type — it defines == over its fields — so
  // `avoid_implementing_value_types` requires anything implementing it to
  // define equality too rather than inheriting Object identity by accident.
  @override
  bool operator ==(Object other) =>
      other is FakeGoogleSignInAccount && other.idToken == idToken;

  @override
  int get hashCode => idToken.hashCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A `FirebaseFunctions` whose callables play out a scripted result.
///
/// Only the sign-up path reaches this. Mission 2.7's tests fake the whole
/// `AuthRepository`, so they never touch it; this is the layer beneath, which
/// is what makes the redemption call itself observable.
class FakeFirebaseFunctions implements FirebaseFunctions {
  FakeFirebaseFunctions({this.throwsOnCall});

  /// Raised by the callable, or null for success.
  ///
  /// Typed as `Exception` rather than `Object`: `only_throw_errors` is an
  /// analyzer error under ADR-021, and a callable cannot raise anything else.
  final Exception? throwsOnCall;

  /// Names of the callables that were invoked, in order.
  final List<String> calledNames = <String>[];

  /// Payloads passed to them, in order.
  final List<Object?> calledWith = <Object?>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _FakeHttpsCallable(this, name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpsCallable implements HttpsCallable {
  _FakeHttpsCallable(this._functions, this._name);

  final FakeFirebaseFunctions _functions;
  final String _name;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    _functions.calledNames.add(_name);
    _functions.calledWith.add(parameters);

    final Exception? failure = _functions.throwsOnCall;
    if (failure != null) {
      throw failure;
    }
    return _FakeHttpsCallableResult<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The repository ignores the result body, so this carries nothing.
class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
