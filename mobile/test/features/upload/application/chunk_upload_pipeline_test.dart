import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';
import 'package:mobile/features/upload/application/chunk_upload_pipeline.dart';
import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';
import 'package:mobile/features/upload/domain/entities/upload_failure_cause.dart';
import 'package:mobile/features/upload/domain/repositories/chunk_upload_api.dart';

import '../../../core/time/fakes/fake_clock.dart';
import '../../../core/upload/fakes/metadata_document_builders.dart';
import '../../../core/upload/fakes/upload_port_fakes.dart';

/// Volume 5 Chapter 5.10's step sequencing, and A-068 Guard 1's verdict.
void main() {
  UploadableChunk chunkFor(String id) => UploadableChunk(
    chunkId: id,
    sessionId: 'sess_e810',
    sequenceIndex: 3,
    sessionStartedAt: DateTime.utc(2026, 8, 15, 9),
    localFilePath: '/docs/recordings/sess_e810/0003.mp4',
    fileSizeBytes: 512000000,
    checksumSha256: 'abc123',
  );

  ({
    ChunkUploadPipeline pipeline,
    FakeChunkUploadSource source,
    FakeSessionRegistrar registrar,
    _RecordingApi api,
  })
  build({
    ChunkMetadataDocument? document,
    List<UploadableChunk>? queued,
    _RecordingApi? api,
  }) {
    final FakeChunkUploadSource source = FakeChunkUploadSource(
      queued: queued ?? <UploadableChunk>[chunkFor('chk_1')],
    );
    final FakeSessionRegistrar registrar = FakeSessionRegistrar();
    final _RecordingApi backend = api ?? _RecordingApi();
    return (
      pipeline: ChunkUploadPipeline(
        clock: FakeClock(),
        uploadSource: source,
        metadataSource: FakeChunkMetadataSource(
          documents: <String, ChunkMetadataDocument>{
            'chk_1': document ?? completeIdentityDocument(),
          },
        ),
        sessionRegistrar: registrar,
        uploadApi: backend,
      ),
      source: source,
      registrar: registrar,
      api: backend,
    );
  }

  group('A-068 Guard 1 — sits before step 1', () {
    test('a real unsourced chunk is refused, and nothing is sent', () async {
      // The state every chunk recorded on a device is actually in.
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build(document: unsourcedIdentityDocument());

      final UploadOutcome? outcome = await t.pipeline.uploadNext();

      expect(outcome!.cause, UploadFailureCause.identityIncomplete);
      // Not silently skipped, not silently sent — A-068's exact wording.
      expect(t.source.transitions, <String>['claim:chk_1', 'failed:chk_1']);
      // The guard is before step 1, so the session was never even resolved.
      expect(t.registrar.asked, isEmpty);
      expect(t.api.calls, isEmpty);
    });

    test('the refusal names each missing field, per Ch. 2.9 §2', () async {
      final UploadOutcome outcome = (await build(
        document: unsourcedIdentityDocument(),
      ).pipeline.uploadNext())!;

      expect(outcome.detail, contains('project_id'));
      expect(outcome.detail, contains('task_id'));
      expect(outcome.detail, contains('collector_id'));
      expect(outcome.detail, contains('device_id'));
    });

    test('it is terminal, so no automatic retry applies', () async {
      // Chapter 5.13 §1: terminal device-side failures are "not retried
      // automatically". Nothing about the stored row changes on a retry.
      final UploadOutcome outcome = (await build(
        document: unsourcedIdentityDocument(),
      ).pipeline.uploadNext())!;

      expect(outcome.isRetryable, isFalse);
      expect(UploadFailureCause.identityIncomplete.isTransient, isFalse);
    });

    test('a synthetic complete-identity chunk passes the guard', () async {
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build();

      final UploadOutcome outcome = (await t.pipeline.uploadNext())!;

      expect(outcome.isComplete, isTrue);
      expect(t.api.calls.first, 'register');
    });

    test('a missing metadata row fails rather than sending blanks', () async {
      final FakeChunkUploadSource source = FakeChunkUploadSource(
        queued: <UploadableChunk>[chunkFor('chk_missing')],
      );
      final _RecordingApi api = _RecordingApi();
      final ChunkUploadPipeline pipeline = ChunkUploadPipeline(
        clock: FakeClock(),
        uploadSource: source,
        metadataSource: FakeChunkMetadataSource(),
        sessionRegistrar: FakeSessionRegistrar(),
        uploadApi: api,
      );

      final UploadOutcome outcome = (await pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.metadataMissing);
      expect(api.calls, isEmpty);
    });
  });

  group('A-191 — steps 3 and 4 swapped against Ch 5.10 §1', () {
    // The chapter lists the status PATCH as step 3 and the metadata POST as
    // step 4. BR-21 makes that impossible: `complete_chunk()` refuses while
    // `chunk_metadata.verified_at` is null, so step 3 would be refused for
    // every chunk, always. This group asserts the order that works, and is
    // named for the amendment rather than the chapter so the suite says what
    // is true and why.
    test('register, upload, metadata, confirm', () async {
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build();

      await t.pipeline.uploadNext();

      expect(t.api.calls, <String>[
        'register',
        'upload',
        'metadata',
        'confirm',
      ]);
    });

    test(
      'the object key is recorded from the response, not composed',
      () async {
        // Volume 4 Ch. 4.10 §2 step 1 — the Lambda computes it and returns it.
        final ({
          ChunkUploadPipeline pipeline,
          FakeChunkUploadSource source,
          FakeSessionRegistrar registrar,
          _RecordingApi api,
        })
        t = build();

        await t.pipeline.uploadNext();

        expect(t.source.objectKeys['chk_1'], _RecordingApi.objectKey);
      },
    );

    test('step 3 sends the wire vocabulary Volume 4 fixes', () async {
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build();

      await t.pipeline.uploadNext();

      expect(t.api.confirmedStatus, ChunkUploadStatus.complete.wireName);
      expect(t.api.confirmedStatus, 'complete');
    });

    test('step 4 posts the document unchanged', () async {
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build();

      await t.pipeline.uploadNext();

      expect(t.api.postedDocument, completeIdentityDocument().toJson());
    });

    test(
      'the session is resolved through the registrar, not assumed',
      () async {
        final ({
          ChunkUploadPipeline pipeline,
          FakeChunkUploadSource source,
          FakeSessionRegistrar registrar,
          _RecordingApi api,
        })
        t = build();

        await t.pipeline.uploadNext();

        expect(t.registrar.asked, <String>['sess_e810']);
        expect(t.api.registeredSessionId, 'srv_sess_1');
      },
    );
  });

  group('A-073 — complete is written after step 4, not step 3', () {
    test('the local complete follows the metadata POST', () async {
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build();

      await t.pipeline.uploadNext();

      expect(t.source.transitions.last, 'complete:chk_1');
      // A-073's claim is the line above: the LOCAL complete follows the remote
      // work, because BR-08 makes `complete` the point a chunk becomes
      // deletable. Which remote call happens to be last is incidental to that
      // claim, and A-191 changed it from the metadata POST to the status PATCH.
      expect(t.api.calls.last, 'confirm');
    });

    test(
      'a metadata failure leaves the chunk failed, never complete',
      () async {
        // BR-08 makes `complete` the point a chunk becomes deletable
        // (Ch. 5.15). Marking it at step 3 would let a chunk whose metadata
        // never landed be cleaned up.
        final _RecordingApi api = _RecordingApi()..failOn = 'metadata';
        final ({
          ChunkUploadPipeline pipeline,
          FakeChunkUploadSource source,
          FakeSessionRegistrar registrar,
          _RecordingApi api,
        })
        t = build(api: api);

        final UploadOutcome outcome = (await t.pipeline.uploadNext())!;

        expect(outcome.isComplete, isFalse);
        expect(t.source.transitions, isNot(contains('complete:chk_1')));

        // Mission 4.4 changed what happens next, and this assertion changed
        // with it. A metadata POST failure is a transport failure, which
        // Chapter 5.13 §1 classifies as **transient** — "never surfaced to the
        // Collector as Failed until attempts are exhausted". The pipeline
        // therefore leaves the row `uploading` and reports; whether six
        // attempts are spent is UploadDispatcher's question.
        expect(t.source.transitions, isNot(contains('failed:chk_1')));
        expect(outcome.isRetryable, isTrue);
        expect(outcome.attemptCount, 1);
      },
    );
  });

  group('cancellation is not failure', () {
    test('a cancelled upload releases the chunk back to queued', () async {
      final _RecordingApi api = _RecordingApi()..cancelOnUpload = true;
      final ({
        ChunkUploadPipeline pipeline,
        FakeChunkUploadSource source,
        FakeSessionRegistrar registrar,
        _RecordingApi api,
      })
      t = build(api: api);

      final UploadOutcome outcome = (await t.pipeline.uploadNext(
        cancelSignal: Future<void>.value(),
      ))!;

      expect(outcome.isCancelled, isTrue);
      // Chapter 5.13 §1 has no row for a deliberate pause, so it must not
      // consume one of §2's six automatic attempts.
      expect(t.source.transitions, contains('released:chk_1'));
      expect(t.source.transitions, isNot(contains('failed:chk_1')));
    });
  });

  group('Chapter 5.13 §1 classification', () {
    test('a 5xx is transient', () async {
      final _RecordingApi api = _RecordingApi()
        ..failOn = 'register'
        ..failureStatus = 503;

      final UploadOutcome outcome = (await build(
        api: api,
      ).pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.transportFailure);
      expect(outcome.isRetryable, isTrue);
    });

    test('a 4xx is terminal, server-side', () async {
      final _RecordingApi api = _RecordingApi()
        ..failOn = 'register'
        ..failureStatus = 403;

      final UploadOutcome outcome = (await build(
        api: api,
      ).pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.rejectedByBackend);
      expect(outcome.isRetryable, isFalse);
    });

    test('a timeout is transient', () async {
      final _RecordingApi api = _RecordingApi()
        ..failOn = 'register'
        ..failureCode = ErrorCode.networkTimeout;

      final UploadOutcome outcome = (await build(
        api: api,
      ).pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.transportFailure);
    });

    test('a missing local file is terminal, device-side', () async {
      final _RecordingApi api = _RecordingApi()
        ..failOn = 'upload'
        ..failureCode = ErrorCode.storageNotFound;

      final UploadOutcome outcome = (await build(
        api: api,
      ).pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.fileUnavailable);
      expect(outcome.isRetryable, isFalse);
    });

    test('a malformed response is terminal', () async {
      final _RecordingApi api = _RecordingApi()
        ..failOn = 'register'
        ..failureCode = ErrorCode.networkSerialization;

      final UploadOutcome outcome = (await build(
        api: api,
      ).pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.malformedResponse);
    });

    test('a session with no Task is terminal, device-side', () async {
      final FakeChunkUploadSource source = FakeChunkUploadSource(
        queued: <UploadableChunk>[chunkFor('chk_1')],
      );
      final _RecordingApi api = _RecordingApi();
      final ChunkUploadPipeline pipeline = ChunkUploadPipeline(
        clock: FakeClock(),
        uploadSource: source,
        metadataSource: FakeChunkMetadataSource(
          documents: <String, ChunkMetadataDocument>{
            'chk_1': completeIdentityDocument(),
          },
        ),
        sessionRegistrar: FakeSessionRegistrar()..hasNoTask = true,
        uploadApi: api,
      );

      final UploadOutcome outcome = (await pipeline.uploadNext())!;

      expect(outcome.cause, UploadFailureCause.sessionUnregisterable);
      expect(outcome.isRetryable, isFalse);
      expect(api.calls, isEmpty);
    });
  });

  group('claiming', () {
    test('an empty queue returns null, not an outcome', () async {
      // "Idle" and "finished" must not be the same answer.
      final ChunkUploadPipeline pipeline = ChunkUploadPipeline(
        clock: FakeClock(),
        uploadSource: FakeChunkUploadSource(),
        metadataSource: FakeChunkMetadataSource(),
        sessionRegistrar: FakeSessionRegistrar(),
        uploadApi: _RecordingApi(),
      );

      expect(await pipeline.uploadNext(), isNull);
    });

    test(
      'a storage failure while claiming is reported, not swallowed',
      () async {
        final ChunkUploadPipeline pipeline = ChunkUploadPipeline(
          clock: FakeClock(),
          uploadSource: FakeChunkUploadSource()..failOnClaim = true,
          metadataSource: FakeChunkMetadataSource(),
          sessionRegistrar: FakeSessionRegistrar(),
          uploadApi: _RecordingApi(),
        );

        final UploadOutcome outcome = (await pipeline.uploadNext())!;

        expect(outcome.cause, UploadFailureCause.storageFailure);
        expect(outcome.chunkId, isNull);
      },
    );

    test(
      'a storage failure reading metadata fails the claimed chunk',
      () async {
        final FakeChunkUploadSource source = FakeChunkUploadSource(
          queued: <UploadableChunk>[chunkFor('chk_1')],
        );
        final ChunkUploadPipeline pipeline = ChunkUploadPipeline(
          clock: FakeClock(),
          uploadSource: source,
          metadataSource: FakeChunkMetadataSource()..failOnRead = true,
          sessionRegistrar: FakeSessionRegistrar(),
          uploadApi: _RecordingApi(),
        );

        final UploadOutcome outcome = (await pipeline.uploadNext())!;

        expect(outcome.cause, UploadFailureCause.storageFailure);

        // As above: `storageFailure` is transient (a device-storage fault
        // rather than a fault in the chunk), so Chapter 5.13 §1 forbids
        // surfacing it as Failed before the budget is spent. The row stays
        // `uploading` for the dispatcher to settle.
        expect(source.transitions, isNot(contains('failed:chk_1')));
        expect(outcome.isRetryable, isTrue);
      },
    );
  });

  group('UploadOutcome', () {
    test('toString distinguishes the three outcomes', () {
      expect(
        const UploadOutcome.complete(chunkId: 'a').toString(),
        'UploadOutcome.complete(a)',
      );
      expect(
        const UploadOutcome.cancelled(chunkId: 'a').toString(),
        'UploadOutcome.cancelled(a)',
      );
      expect(
        const UploadOutcome.failed(
          chunkId: 'a',
          cause: UploadFailureCause.fileUnavailable,
          detail: 'gone',
        ).toString(),
        'UploadOutcome.failed(a, fileUnavailable: gone)',
      );
    });

    test('only a transient cause is retryable', () {
      for (final UploadFailureCause cause in UploadFailureCause.values) {
        expect(
          UploadOutcome.failed(
            chunkId: 'a',
            cause: cause,
            detail: '',
          ).isRetryable,
          cause.isTransient,
        );
      }
    });

    test('a complete outcome is not retryable', () {
      expect(const UploadOutcome.complete(chunkId: 'a').isRetryable, isFalse);
    });
  });
}

/// A `ChunkUploadApi` that records its calls and can be made to fail.
///
/// Tier 2: no transport at all. `FakeBackendAdapter` covers the request
/// bodies and envelope parsing this deliberately skips.
class _RecordingApi implements ChunkUploadApi {
  static const String objectKey = 'org_9f2/proj_4a1/task_7c3/sess/0003_c.mp4';

  final List<String> calls = <String>[];

  String? failOn;
  int? failureStatus;
  ErrorCode? failureCode;
  bool cancelOnUpload = false;

  String? registeredSessionId;
  String? confirmedStatus;
  Map<String, Object?>? postedDocument;

  void _maybeFail(String step) {
    if (failOn != step) {
      return;
    }
    throw NetworkException(
      errorCode: failureCode ?? ErrorCode.networkServerError,
      message: 'scripted $step failure',
      statusCode: failureStatus,
    );
  }

  @override
  Future<ChunkRegistration> registerChunk({
    required String remoteSessionId,
    required String chunkId,
    required int sequenceIndex,
    required int fileSizeBytes,
    required String checksumSha256,
  }) async {
    calls.add('register');
    registeredSessionId = remoteSessionId;
    _maybeFail('register');
    return const ChunkRegistration(
      chunkId: 'chk_1',
      s3ObjectKey: objectKey,
      uploadUrls: <String>['https://s3.example/part-1'],
    );
  }

  @override
  Future<void> uploadObject({
    required ChunkRegistration registration,
    required String localFilePath,
    required int fileSizeBytes,
    ChunkUploadProgress? onProgress,
    Future<void>? cancelSignal,
  }) async {
    calls.add('upload');
    if (cancelOnUpload) {
      throw const NetworkException(
        errorCode: ErrorCode.networkCancelled,
        message: 'scripted cancellation',
      );
    }
    _maybeFail('upload');
    onProgress?.call(fileSizeBytes, fileSizeBytes);
  }

  @override
  Future<void> confirmStatus({
    required String chunkId,
    required String status,
  }) async {
    calls.add('confirm');
    confirmedStatus = status;
    _maybeFail('confirm');
  }

  @override
  Future<void> postMetadata({
    required String chunkId,
    required Map<String, Object?> document,
  }) async {
    calls.add('metadata');
    postedDocument = document;
    _maybeFail('metadata');
  }
}
