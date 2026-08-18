import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/invite_code_notifier.dart';
import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/repositories/invite_code_repository.dart';
import 'package:mobile/features/auth/presentation/admin_invite_codes_screen.dart';

/// The Admin invite-code surface, which had 1.8% coverage before Mission 2.8.
///
/// It is a small form, but it is the surface that mints organisation
/// membership, so the properties worth pinning are the ones that stop it
/// minting the wrong thing: the org comes from the admin's own claim and not
/// from a field, and a refusal is shown rather than swallowed.
void main() {
  const User admin = User(
    uid: 'a1',
    email: 'admin@example.com',
    role: Role.admin,
    orgId: 'org-42',
    emailVerified: true,
  );

  Future<_FakeInviteRepository> pump(
    WidgetTester tester, {
    User? signedInAs = admin,
    AuthenticationException? issueThrows,
  }) async {
    final _FakeInviteRepository invites = _FakeInviteRepository(
      throws: issueThrows,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(signedInAs),
        ),
        inviteCodeRepositoryProvider.overrideWithValue(invites),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminInviteCodesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return invites;
  }

  group('the organisation is not a field', () {
    testWidgets("the admin's own org is used and shown", (
      WidgetTester tester,
    ) async {
      // Offering an org field would imply a choice the Firestore rules refuse:
      // the rule requires request.auth.token.org_id to match the document's.
      final _FakeInviteRepository invites = await pump(tester);

      expect(find.textContaining('org-42'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(invites.lastOrgId, 'org-42');
    });

    testWidgets('signed out shows a notice and no form', (
      WidgetTester tester,
    ) async {
      await pump(tester, signedInAs: null);

      expect(find.byKey(const Key('invite.signedOut')), findsOneWidget);
      expect(find.byKey(const Key('invite.submit')), findsNothing);
    });
  });

  group('issuing a code', () {
    testWidgets('the generated code is shown once, with a copy action', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.issued')), findsOneWidget);
      expect(find.byKey(const Key('invite.copy')), findsOneWidget);
      expect(find.textContaining('cannot be shown again'), findsOneWidget);
    });

    testWidgets('an empty use count means unlimited, not zero', (
      WidgetTester tester,
    ) async {
      final _FakeInviteRepository invites = await pump(tester);

      await tester.enterText(find.byKey(const Key('invite.uses')), '');
      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(invites.lastRemainingUses, isNull);
      expect(find.textContaining('Unlimited uses'), findsOneWidget);
    });

    testWidgets('a use count is passed through as entered', (
      WidgetTester tester,
    ) async {
      final _FakeInviteRepository invites = await pump(tester);

      await tester.enterText(find.byKey(const Key('invite.uses')), '5');
      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(invites.lastRemainingUses, 5);
    });

    testWidgets('zero uses is rejected before a write', (
      WidgetTester tester,
    ) async {
      // A code with zero uses is dead on arrival, and the function would
      // report it as invalid — confusing the admin who just made it.
      final _FakeInviteRepository invites = await pump(tester);

      await tester.enterText(find.byKey(const Key('invite.uses')), '0');
      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(invites.issueCalls, 0);
      expect(find.textContaining('1 or more'), findsOneWidget);
    });

    testWidgets('the expiry sent is in the future', (
      WidgetTester tester,
    ) async {
      final _FakeInviteRepository invites = await pump(tester);

      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(invites.lastExpiresAt!.isAfter(DateTime.now().toUtc()), isTrue);
    });
  });

  group('a refusal is shown, not swallowed', () {
    testWidgets('permission-denied renders the specific message', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        issueThrows: const AuthenticationException(
          errorCode: ErrorCode.authForbidden,
          message: 'internal wording',
        ),
      );

      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.error')), findsOneWidget);
      expect(find.byKey(const Key('invite.issued')), findsNothing);
      expect(find.textContaining('internal wording'), findsNothing);
    });
  });
}

class _FakeInviteRepository implements InviteCodeRepository {
  _FakeInviteRepository({this.throws});

  final AuthenticationException? throws;

  int issueCalls = 0;
  String? lastOrgId;
  int? lastRemainingUses;
  DateTime? lastExpiresAt;

  @override
  Future<OrgInviteCode> issue({
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  }) async {
    issueCalls += 1;
    lastOrgId = orgId;
    lastRemainingUses = remainingUses;
    lastExpiresAt = expiresAt;

    final AuthenticationException? failure = throws;
    if (failure != null) {
      throw failure;
    }
    return OrgInviteCode(
      code: 'ABCDEFGHJK',
      orgId: orgId,
      expiresAt: expiresAt,
      remainingUses: remainingUses,
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._user);

  final User? _user;

  /// A-177: `AuthNotifier.build` resolves the first session from this stream
  /// and no longer calls `restoreSession`, so an empty stream leaves `build`
  /// awaiting forever and every test here times out rather than fails.
  @override
  Stream<Session> get sessionChanges => Stream<Session>.fromIterable(<Session>[
    const Session.unknown(),
    if (_user == null)
      const Session.unauthenticated()
    else
      Session.authenticated(_user),
  ]);

  @override
  Future<Session> restoreSession() async => _user == null
      ? const Session.unauthenticated()
      : Session.authenticated(_user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
