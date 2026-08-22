import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/identity/providers/identity_ports.dart';
import 'package:mobile/core/identity/selected_task.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';
import 'package:mobile/features/auth/domain/entities/session.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/recording/data/chunk_metadata_assembler.dart';
import 'package:mobile/features/recording/data/platform_device_context.dart';
import 'package:mobile/features/recording/data/platform_task_context.dart';
import 'package:mobile/features/recording/data/unavailable_capture_conditions_reader.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/chunk_metadata.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';

/// The smallest repository that can drive `AuthNotifier` through a sign-in and
/// a sign-out. Seeded on subscription for A-177's reason: `build` resolves the
/// first session from this stream, so a silent stream leaves it awaiting.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._restored);

  final Session _restored;
  late final StreamController<Session> _sessions = StreamController<Session>(
    onListen: () {
      _sessions.add(const Session.unknown());
      _sessions.add(_restored);
    },
  );

  void emit(Session session) => _sessions.add(session);

  @override
  Stream<Session> get sessionChanges => _sessions.stream;

  @override
  Future<Session> restoreSession() async => _restored;

  @override
  Future<void> signOut() async => emit(const Session.unauthenticated());

  @override
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<User> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<User> signUpWithEmailPassword({
    required String email,
    required String password,
    String? inviteCode,
  }) => throw UnimplementedError();

  @override
  Future<User> signUpWithGoogle({String? inviteCode}) =>
      throw UnimplementedError();
}

/// **The composition root's identity wiring, which no test referenced before
/// Mission 8.1.**
///
/// `taskContextProvider` and `deviceContextProvider` had zero references
/// anywhere under `test/`. They are the two ports that decide what a recorded
/// chunk claims about itself, and open items 1, 5 and 11 were closed on the
/// strength of reading how `main.dart` overrides them — not on a test.
///
/// ## What this file does and does not prove
///
/// It rebuilds those two overrides with the same expressions `main.dart` uses
/// and asserts the behaviour they produce. **It cannot prove `main.dart` still
/// contains them**: editing the composition root would not fail this file. That
/// residual gap is stated rather than papered over — closing it would need the
/// overrides extracted to a named function, which is a production change and
/// outside Mission 8.1's scope.
///
/// What it does prove is the contract those items rest on: a selected Task and
/// a signed-in Collector become a complete identity, and the absence of either
/// becomes an incomplete one that A-068's Guard 1 refuses rather than uploads.
void main() {
  // No binding, and no `testWidgets`. This file pumps nothing: it builds a
  // ProviderContainer and reads two providers through it. What it integrates
  // is the PROVIDER GRAPH, not a widget tree — the composition root's wiring
  // is not a UI concern, and pretending it needs a tester would drag the
  // fake-async zone in with it, which is what made the first attempt fail on
  // pending timers.

  const User collector = User(
    uid: 'firebase-uid-1',
    backendUserId: '11111111-1111-4111-8111-111111111111',
    email: 'collector@example.com',
    role: Role.collector,
    orgId: '00000000-0000-4000-8000-0000000000d1',
    emailVerified: true,
  );

  const SelectedTask selection = SelectedTask(
    projectId: 'prj_9f21',
    taskId: 'tsk_7c3',
  );

  final DateTime startedAt = DateTime.utc(2026, 8, 22, 9);
  final RecordingSession session = RecordingSession(
    sessionId: 'sess_e810',
    zoomFactor: 0.6,
    startedAt: startedAt,
  );
  final ChunkProcessingJob job = ChunkProcessingJob(
    chunkId: 'chk_5b2a',
    sequenceIndex: 3,
    filePath: '/recordings/sess_e810/0003.mp4',
    startedAt: startedAt.add(const Duration(minutes: 10)),
  );
  const ChunkIntegrity integrity = ChunkIntegrity(
    checksumSha256:
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    byteCount: 512000000,
  );

  /// A container wired exactly as `main.dart` wires these two ports.
  Future<(ProviderContainer, _FakeAuthRepository)> boot({
    required Session restored,
  }) async {
    final _FakeAuthRepository repository = _FakeAuthRepository(restored);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        // Verbatim from main.dart: the selection decides both ids, and the
        // unsourced context is what a null selection produces.
        taskContextProvider.overrideWith((Ref ref) {
          final SelectedTask? selected = ref.watch(selectedTaskProvider);
          return selected == null
              ? const PlatformTaskContext.unsourced()
              : PlatformTaskContext(selection: selected);
        }),
        // Verbatim from main.dart, including `watch` rather than `read`.
        deviceContextProvider.overrideWith(
          (Ref ref) => PlatformDeviceContext(
            collectorId:
                ref
                    .watch(authNotifierProvider)
                    .valueOrNull
                    ?.user
                    ?.backendUserId ??
                MetadataIdentity.unsourced,
            deviceId: 'device-1',
            deviceModel: 'OnePlus CPH2707',
            appVersion: '1.0.0+1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // A live subscription, because `read` alone does not keep a provider alive
    // and it would never recompute when the session stream emits again. The
    // widget tree watches this in production; a container with no listener
    // models an app nobody is looking at.
    container.listen(authNotifierProvider, (_, _) {});
    // Resolved before anything reads it, exactly as main.dart does.
    await container.read(authNotifierProvider.future);
    return (container, repository);
  }

  Future<ChunkMetadata> assemble(ProviderContainer container) =>
      ChunkMetadataAssembler(
        taskContext: container.read(taskContextProvider),
        deviceContext: container.read(deviceContextProvider),
        conditionsReader: const UnavailableCaptureConditionsReader(),
      ).generate(
        session: session,
        job: job,
        integrity: integrity,
        chunkStartedAt: startedAt,
      );

  test('a selected Task and a signed-in Collector make a complete '
      'identity', () async {
    final (ProviderContainer container, _) = await boot(
      restored: const Session.authenticated(collector),
    );
    container.read(selectedTaskProvider.notifier).select(selection);

    final ChunkMetadata metadata = await assemble(container);

    expect(metadata.identity.projectId, 'prj_9f21');
    expect(metadata.identity.taskId, 'tsk_7c3');
    expect(metadata.identity.sessionId, 'sess_e810');
    expect(metadata.identity.deviceId, 'device-1');
    expect(metadata.identity.isComplete, isTrue);
  });

  test(
    'the Collector id is the backend user id, not the Firebase uid',
    () async {
      // A-206. The metadata route joins `sessions.collector_id`, which is a
      // `users.id`, and refuses a document that disagrees. Both values are
      // non-empty opaque strings from one account, so no test on either side
      // could tell them apart — which is how the Firebase one shipped.
      final (ProviderContainer container, _) = await boot(
        restored: const Session.authenticated(collector),
      );
      container.read(selectedTaskProvider.notifier).select(selection);

      final ChunkMetadata metadata = await assemble(container);

      expect(metadata.identity.collectorId, collector.backendUserId);
      expect(metadata.identity.collectorId, isNot(collector.uid));
    },
  );

  test('no Task selected leaves the identity incomplete, so Guard 1 '
      'refuses the chunk', () async {
    final (ProviderContainer container, _) = await boot(
      restored: const Session.authenticated(collector),
    );

    final ChunkMetadata metadata = await assemble(container);

    expect(metadata.identity.projectId, MetadataIdentity.unsourced);
    expect(metadata.identity.taskId, MetadataIdentity.unsourced);
    expect(metadata.identity.isComplete, isFalse);
  });

  test('signing out mid-session changes what the NEXT chunk is stamped '
      'with', () async {
    // F21, and the reason main.dart uses `ref.watch` rather than `read`. A
    // read would freeze whichever state held at container construction —
    // `unauthenticated`, since the session has not been restored yet — and
    // every chunk of the session would carry a blank Collector.
    //
    // Nothing asserted this before Mission 8.1. The failure it prevents is
    // silent: chunks upload, and their attribution is wrong.
    final (ProviderContainer container, _FakeAuthRepository repository) =
        await boot(restored: const Session.authenticated(collector));
    container.read(selectedTaskProvider.notifier).select(selection);

    final ChunkMetadata before = await assemble(container);
    expect(before.identity.isComplete, isTrue);

    repository.emit(const Session.unauthenticated());
    // One turn of the event loop for the stream event to reach the notifier.
    await Future<void>.delayed(Duration.zero);

    final ChunkMetadata after = await assemble(container);

    expect(after.identity.collectorId, MetadataIdentity.unsourced);
    expect(after.identity.isComplete, isFalse);
    // The Task survives the sign-out: it is a separate port, and forgetting it
    // here would hide which of the two went missing.
    expect(after.identity.taskId, 'tsk_7c3');
  });
}
