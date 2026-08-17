import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';

/// Issues organisation invite codes.
///
/// **TEMPORARY — the implementation is retired at Mission 6/7 (ADR-036).**
/// This interface is not: when issuing moves to a `/v1/...` route, only the
/// class behind it changes, which is the reason the interface exists at all.
///
/// Declared here rather than in `data/` so `application/` and `presentation/`
/// can name the type without importing the implementation — the prohibition
/// ADR-022 states and ADR-001's inversion resolves.
///
/// ## There is no read
///
/// Deliberately. A client that could list or verify codes could enumerate
/// them, which is the attack the Firestore rules deny outright by refusing
/// every client read. Redemption is the only path that reads a code, and it
/// happens on the server.
abstract interface class InviteCodeRepository {
  /// Creates a code for [orgId] and returns it.
  ///
  /// [expiresAt] is compared against the server's clock when the code is
  /// redeemed, never the device's. [remainingUses] is null for unlimited.
  ///
  /// Throws `AuthenticationException` carrying `AUTH_FORBIDDEN` when the
  /// caller is not an admin of [orgId] — a decision the Firestore rules make,
  /// not this application.
  Future<OrgInviteCode> issue({
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  });
}
