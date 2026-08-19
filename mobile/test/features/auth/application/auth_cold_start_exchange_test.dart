import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// The regression guard for gap 11 — A-177.
///
/// **The hole this closes is that nothing could see the bug.** Every cold start
/// for an already-signed-in Collector performed `POST /v1/auth/verify` twice,
/// concurrently: `AuthNotifier.build` subscribed to `sessionChanges` *and*
/// called `restoreSession`, and both reached `AuthRepositoryImpl._toUser`. It
/// shipped in Mission 6.5, survived Mission 6.6's audit and Mission 6.7's
/// security review, and was still there at Mission 7.2 — because a search of
/// `test/` for `auth/verify` returned nothing at all. Every test asserted what
/// the session *was*, none asserted what it *cost*.
///
/// So these tests assert counts, not values. They fail if a second resolution
/// path is ever reintroduced, whatever it returns.
void main() {
  group('a cold start resolves the session exactly once', () {
    test('build never calls restoreSession', () async {
      final _CountingAuthRepository repository = _CountingAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);

      // The whole of gap 11 in one assertion. `restoreSession` remains on the
      // interface; the startup path must not be a second caller of it.
      expect(repository.restoreSessionCalls, 0);
    });

    test('the session stream is subscribed exactly once', () async {
      final _CountingAuthRepository repository = _CountingAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);

      // Reading `sessionChanges` twice would be the same defect wearing a
      // different hat: the getter subscribes to Firebase and maps every event
      // through `_toUser`, so a second subscription is a second exchange.
      expect(repository.sessionChangesSubscriptions, 1);
    });

    test('the resolved state is the one the stream reported', () async {
      final _CountingAuthRepository repository = _CountingAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final AuthState state = await container.read(authNotifierProvider.future);

      // Counting alone would pass if `build` resolved to something wrong and
      // cheap. The value has to survive the change too.
      expect(state, isA<AuthStateAuthenticated>());
      expect((state as AuthStateAuthenticated).user.orgId, 'org-42');
    });
  });
}

/// An [AuthRepository] that counts how it is used.
///
/// Faked with `implements` per testing-standards.md §8; `mocktail` is not a
/// dependency (A-028).
class _CountingAuthRepository implements AuthRepository {
  int restoreSessionCalls = 0;
  int sessionChangesSubscriptions = 0;

  static const User _user = User(
    uid: 'uid-1',
    email: 'someone@example.com',
    role: Role.collector,
    orgId: 'org-42',
    emailVerified: true,
  );

  @override
  Stream<Session> get sessionChanges {
    sessionChangesSubscriptions++;
    return Stream<Session>.fromIterable(<Session>[
      const Session.unknown(),
      const Session.authenticated(_user),
    ]);
  }

  @override
  Future<Session> restoreSession() async {
    restoreSessionCalls++;
    return const Session.authenticated(_user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
