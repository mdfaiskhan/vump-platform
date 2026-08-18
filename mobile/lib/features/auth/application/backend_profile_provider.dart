import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/providers/dio_provider.dart';

/// The signed-in user's profile, read from the backend — Chapter 4.6 §2's
/// `GET /v1/users/me`, *"Current user's profile + role"*.
///
/// ## Why this exists as its own provider
///
/// `AuthRepository` already yields a `User`, and this deliberately does not
/// replace it. That `User` is assembled at sign-in from the token's claims
/// plus the one exchange `POST /v1/auth/verify` performs (ADR-048). This is a
/// *read of the authoritative row*, on demand, through the API Gateway
/// authorizer — a different thing, and the first device-originated caller of a
/// route that sits behind it.
///
/// Chapter 4.7 §2 is what makes the distinction worth keeping: the `users`
/// table is *"the authoritative source if the claim and the table ever
/// disagree"*. A screen showing "who does the backend think I am" is showing
/// the table, not the token.
///
/// ## No new state management
///
/// A `FutureProvider` and nothing else. It reuses the client
/// `vumpApiProvider` already publishes, and the token is attached by
/// `AuthInterceptor`, so nothing here handles a credential or holds state
/// between reads.
final FutureProvider<BackendProfile> backendProfileProvider =
    FutureProvider<BackendProfile>((Ref ref) async {
      final Map<String, Object?> data = await ref
          .watch(vumpApiProvider)
          .get('/users/me', what: 'Loading your profile');
      return BackendProfile.fromJson(data);
    });

/// The three fields `GET /v1/users/me` returns.
///
/// Hand-written rather than generated: it is the only consumer of this shape,
/// and a `freezed` class for three strings would be more build output than
/// code.
class BackendProfile {
  /// Creates a profile.
  const BackendProfile({
    required this.userId,
    required this.orgId,
    required this.role,
  });

  /// Reads the envelope's `data` object.
  ///
  /// Throws [FormatException] rather than substituting defaults: a field
  /// missing here means the backend contract changed, and a screen showing an
  /// empty organisation would hide that.
  factory BackendProfile.fromJson(Map<String, Object?> json) {
    final Object? userId = json['userId'];
    final Object? orgId = json['orgId'];
    final Object? role = json['role'];
    if (userId is! String || orgId is! String || role is! String) {
      throw const FormatException(
        'GET /v1/users/me did not return userId, orgId and role as strings.',
      );
    }
    return BackendProfile(userId: userId, orgId: orgId, role: role);
  }

  /// `users.id` — the backend's own identifier, not the Firebase uid.
  final String userId;

  /// `users.org_id`, the organisation BR-20 scopes every query by.
  final String orgId;

  /// `users.role`, read from the table rather than from the token claim.
  final String role;
}
