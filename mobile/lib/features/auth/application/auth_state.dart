import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// The application's view of who is signed in.
///
/// Volume 3 Chapter 3.9 §3 names this type and fixes its three cases:
/// *"AsyncNotifier&lt;AuthState&gt; (unauthenticated / authenticated-with-role /
/// expired)"*. It *"drives the Role Router (SH-03, Chapter 2.4 §4)"*.
///
/// ## Why this is not the domain `Session`
///
/// `Session` (Mission 2.1) is the shape Firebase produces; this is the shape
/// the UI consumes, and they differ in both directions.
///
/// **`Session.unknown` has no case here, deliberately.** It represents the
/// window before a restore completes, which is exactly what `AsyncLoading`
/// means. Carrying it as data as well would give the UI two ways to spell one
/// state, and `AsyncValue.when` would need a fourth branch that its own
/// `loading:` already covers.
///
/// **`expired` has no counterpart in `Session`.** It is distinct from
/// `unauthenticated`: the difference is whether a session existed and lapsed,
/// which decides whether the login screen explains why the user is back at it.
/// Nothing produces it yet — the silent-refresh behaviour that detects a lapsed
/// session is Mission 2.5 — so it is currently unreachable and typed rather
/// than inferred.
@freezed
sealed class AuthState with _$AuthState {
  /// Nobody is signed in, and nobody was.
  const factory AuthState.unauthenticated() = AuthStateUnauthenticated;

  /// Signed in, with the role the Role Router branches on.
  const factory AuthState.authenticated(User user) = AuthStateAuthenticated;

  /// A session existed and can no longer be renewed.
  ///
  /// Produced by Mission 2.5's session restore, not by this mission.
  const factory AuthState.expired() = AuthStateExpired;

  const AuthState._();

  /// Maps a domain [Session] onto this type.
  ///
  /// [Session.unknown] has no representation and is reported as `null`, which
  /// the notifier renders as `AsyncLoading` rather than as data.
  static AuthState? fromSession(Session session) {
    return switch (session) {
      SessionUnknown() => null,
      SessionUnauthenticated() => const AuthState.unauthenticated(),
      SessionAuthenticated(:final User user) => AuthState.authenticated(user),
    };
  }

  /// The signed-in user, or null in every other state.
  ///
  /// Saves each caller a pattern match when all it needs is the role.
  User? get user => switch (this) {
    AuthStateAuthenticated(:final User user) => user,
    _ => null,
  };
}
