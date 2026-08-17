import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';
import 'package:mobile/features/auth/domain/repositories/invite_code_repository.dart';

/// The repository the Admin invite-code screen drives.
///
/// **Overridden at the composition root**, for the reason
/// `authRepositoryProvider` is: `application/` may not import `data/`
/// (ADR-022), and the implementation lives there.
final Provider<InviteCodeRepository> inviteCodeRepositoryProvider =
    Provider<InviteCodeRepository>(
      (Ref ref) => throw UnimplementedError(
        'inviteCodeRepositoryProvider must be overridden with an '
        'InviteCodeRepository. features/auth/data/ provides '
        'InviteCodeRepositoryImpl.',
      ),
    );

/// Issues invite codes on behalf of the Admin screen.
///
/// **TEMPORARY — retired with the rest of ADR-036 at Mission 6/7.**
///
/// Holds no state of its own. Issuing is a one-shot action whose result the
/// screen displays once, not a value the application observes, so there is no
/// `AsyncNotifier<List<OrgInviteCode>>` here — and there could not be, since
/// the Firestore rules deny every client read and nothing can list codes.
///
/// Returns the outcome rather than throwing, the shape `AuthNotifier` uses and
/// for the same reason: the caller renders a `Failure`, and
/// error-handling.md §26 makes this the last layer that may catch an
/// `AppException`.
class InviteCodeIssuer {
  const InviteCodeIssuer(this._repository);

  final InviteCodeRepository _repository;

  /// Issues a code, or returns the failure to render.
  Future<({OrgInviteCode? code, Failure? failure})> issue({
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  }) async {
    try {
      final OrgInviteCode code = await _repository.issue(
        orgId: orgId,
        expiresAt: expiresAt,
        remainingUses: remainingUses,
      );
      return (code: code, failure: null);
    } on AppException catch (exception) {
      return (code: null, failure: Failure.fromException(exception));
    }
  }
}

/// The issuer the Admin screen calls.
final Provider<InviteCodeIssuer> inviteCodeIssuerProvider =
    Provider<InviteCodeIssuer>(
      (Ref ref) => InviteCodeIssuer(ref.watch(inviteCodeRepositoryProvider)),
    );
