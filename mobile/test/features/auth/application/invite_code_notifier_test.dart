import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/auth/application/invite_code_notifier.dart';
import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';
import 'package:mobile/features/auth/domain/repositories/invite_code_repository.dart';

/// `InviteCodeIssuer`, which had no coverage at all before Mission 2.8.
///
/// It is small, but it is the layer that decides whether an Admin sees a code
/// or an explanation — and error-handling.md §26 makes it the last place an
/// `AppException` may be caught, so a leak here reaches a widget.
void main() {
  ProviderContainer containerWith(InviteCodeRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        inviteCodeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final DateTime expiry = DateTime.utc(2026, 9, 1);

  test('a successful issue returns the code and no failure', () async {
    final ProviderContainer container = containerWith(_FakeRepository());

    final ({OrgInviteCode? code, Failure? failure}) result = await container
        .read(inviteCodeIssuerProvider)
        .issue(orgId: 'org-1', expiresAt: expiry, remainingUses: 3);

    expect(result.failure, isNull);
    expect(result.code?.orgId, 'org-1');
    expect(result.code?.remainingUses, 3);
  });

  test('unlimited uses passes null through rather than a number', () async {
    // Null means unlimited in the entity, and the function does not decrement
    // a null. Substituting a large number here would silently cap it.
    final _FakeRepository repository = _FakeRepository();
    final ProviderContainer container = containerWith(repository);

    await container
        .read(inviteCodeIssuerProvider)
        .issue(orgId: 'org-1', expiresAt: expiry);

    expect(repository.lastRemainingUses, isNull);
  });

  test('a refused write returns a Failure carrying its code', () async {
    // What an Admin whose claim does not match the organisation gets. The
    // Firestore rule is what refuses; this is how the refusal is reported.
    final ProviderContainer container = containerWith(
      _FakeRepository(
        throws: const AuthenticationException(
          errorCode: ErrorCode.authForbidden,
          message: 'permission-denied',
        ),
      ),
    );

    final ({OrgInviteCode? code, Failure? failure}) result = await container
        .read(inviteCodeIssuerProvider)
        .issue(orgId: 'other-org', expiresAt: expiry);

    expect(result.code, isNull);
    expect(result.failure?.code, ErrorCode.authForbidden);
  });

  test('no AppException escapes to the caller', () async {
    // presentation/ must never receive an exception — §26.
    final ProviderContainer container = containerWith(
      _FakeRepository(
        throws: const AuthenticationException(
          errorCode: ErrorCode.unknown,
          message: 'boom',
        ),
      ),
    );

    await expectLater(
      container
          .read(inviteCodeIssuerProvider)
          .issue(orgId: 'org-1', expiresAt: expiry),
      completes,
    );
  });
}

class _FakeRepository implements InviteCodeRepository {
  _FakeRepository({this.throws});

  final AuthenticationException? throws;
  int? lastRemainingUses;

  @override
  Future<OrgInviteCode> issue({
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  }) async {
    final AuthenticationException? failure = throws;
    if (failure != null) {
      throw failure;
    }
    lastRemainingUses = remainingUses;
    return OrgInviteCode(
      code: 'ABCDEFGHJK',
      orgId: orgId,
      expiresAt: expiresAt,
      remainingUses: remainingUses,
    );
  }
}
