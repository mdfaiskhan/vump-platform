import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/network/interfaces/auth_token_source.dart';
import 'package:mobile/core/network/network_config.dart';
import 'package:mobile/core/network/s3_transfer_client.dart';
import 'package:mobile/core/network/vump_api.dart';
import 'package:mobile/features/upload/data/chunk_upload_api_impl.dart';
import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';

import 'fakes/fake_backend_adapter.dart';

/// The real client stack, over a scripted socket.
///
/// Everything below `ChunkUploadApiImpl` is genuine here — `DioClient` with
/// its full interceptor chain, `VumpApi`'s envelope handling, the real
/// `S3TransferClient`. Only the `HttpClientAdapter` is fake. That placement is
/// deliberate: a faked repository would leave Chapter 4.6 §5's request body
/// and Chapter 4.6 §1's envelope parsing untested, which is where a contract
/// mismatch would actually live.
void main() {
  late Directory tempDir;
  late File chunkFile;

  /// 24 bytes, so a 3-part split is 8 bytes each and the ranges are checkable.
  const String fileContents = 'AAAAAAAABBBBBBBBCCCCCCCC';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vump_upload_test');
    chunkFile = File('${tempDir.path}/0003.mp4')
      ..writeAsStringSync(fileContents);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) build({
    int partCount = 1,
    String? token = 'firebase-id-token',
  }) {
    final FakeBackendAdapter backend = FakeBackendAdapter(partCount: partCount);

    final DioClient client = DioClient(
      config: NetworkConfig.forEnvironment(AppEnvironment.production),
      logger: _silentLogger(),
      tokenSource: _FixedTokenSource(token),
    )..dio.httpClientAdapter = backend;

    final Dio s3Dio = Dio()..httpClientAdapter = backend;

    return (
      api: ChunkUploadApiImpl(
        backend: VumpApi(client: client),
        transfer: S3TransferClient(logger: _silentLogger(), dio: s3Dio),
      ),
      backend: backend,
    );
  }

  Future<ChunkRegistration> register(ChunkUploadApiImpl api) =>
      api.registerChunk(
        remoteSessionId: 'srv_sess_1',
        chunkId: 'chk_1',
        sequenceIndex: 3,
        fileSizeBytes: fileContents.length,
        checksumSha256: 'abc123',
      );

  group('THE assertion — no Vump credential ever reaches S3', () {
    test('the S3 PUT carries no Authorization header', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      final ChunkRegistration registration = await register(t.api);

      await t.api.uploadObject(
        registration: registration,
        localFilePath: chunkFile.path,
        fileSizeBytes: fileContents.length,
      );

      final List<RecordedRequest> s3 = t.backend.s3Requests.toList();
      expect(s3, isNotEmpty, reason: 'the PUT must actually have happened');
      for (final RecordedRequest request in s3) {
        expect(
          request.hasAuthorization,
          isFalse,
          reason:
              'AWS SigV4 rejects a presigned request carrying a conflicting '
              'Authorization header, and sending one would also leak a '
              'Firebase ID token to Amazon.',
        );
      }
    });

    test('and the same run DID send one to the Vump backend', () async {
      // Without this, the assertion above would pass just as happily if the
      // token source were broken and no request anywhere were authenticated.
      // The two together prove the split is real rather than absent.
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      await register(t.api);

      final List<RecordedRequest> backendCalls = t.backend.backendRequests
          .toList();
      expect(backendCalls, isNotEmpty);
      expect(
        backendCalls.every((RecordedRequest r) => r.hasAuthorization),
        isTrue,
        reason: 'Ch. 4.6 §1 requires a bearer token on every Vump request',
      );
    });

    test('the check is case-insensitive, as HTTP headers are', () {
      final RecordedRequest request = RecordedRequest(
        method: 'PUT',
        uri: Uri.parse('https://s3.example/o'),
        headers: <String, List<String>>{
          'AUTHORIZATION': <String>['Bearer x'],
        },
        body: null,
      );

      // A test asserting on the wrong casing would pass while the header was
      // present — the exact false negative this fake exists to prevent.
      expect(request.hasAuthorization, isTrue);
    });
  });

  group('Chapter 4.6 §5 — the registration contract', () {
    test('the body is exactly the three fields, and no ids', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      await register(t.api);

      final RecordedRequest request = t.backend.backendRequests.first;
      expect(request.body, <String, Object?>{
        'sequence_index': 3,
        'file_size_bytes': fileContents.length,
        'checksum_sha256': 'abc123',
      });
      // The Lambda composes the key (Volume 4 Ch. 4.10 §2), so the client
      // sends no org_id, project_id or task_id.
      expect(request.body!.containsKey('org_id'), isFalse);
      expect(request.body!.containsKey('project_id'), isFalse);
      expect(request.body!.containsKey('task_id'), isFalse);
    });

    test('the path is /v1/sessions/{id}/chunks', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      await register(t.api);

      expect(
        t.backend.backendRequests.first.uri.path,
        '/v1/sessions/srv_sess_1/chunks',
      );
    });

    test('the key and URLs come back off the response', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build(
        partCount: 3,
      );

      final ChunkRegistration registration = await register(t.api);

      expect(registration.s3ObjectKey, t.backend.s3ObjectKey);
      expect(registration.uploadUrls, hasLength(3));
      expect(registration.hasParts, isTrue);
    });

    test('an echoed chunk_id that differs is refused', () async {
      // Steps 3 and 4 are keyed by {id}. A mismatch would address a different
      // chunk than the one whose bytes step 2 uploaded.
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      t.backend.registeredChunkId = 'chk_SOMETHING_ELSE';

      await expectLater(
        register(t.api),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.networkSerialization,
          ),
        ),
      );
    });

    test('a refusal carries the backend code, not a bare status', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      t.backend.errorOverrides['POST /chunks'] = <String, Object?>{
        'code': 'CHUNK_ALREADY_REGISTERED',
        'message': 'This chunk is registered.',
      };

      await expectLater(
        register(t.api),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.message,
            'message',
            contains('CHUNK_ALREADY_REGISTERED'),
          ),
        ),
      );
    });
  });

  group('Chapter 5.10 §1 step 2 — the multipart split', () {
    test('the backend part count decides how many PUTs happen', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build(
        partCount: 3,
      );
      final ChunkRegistration registration = await register(t.api);

      await t.api.uploadObject(
        registration: registration,
        localFilePath: chunkFile.path,
        fileSizeBytes: fileContents.length,
      );

      expect(t.backend.s3Requests, hasLength(3));
    });

    test('the parts go to the presigned URLs the backend issued', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build(
        partCount: 2,
      );
      final ChunkRegistration registration = await register(t.api);

      await t.api.uploadObject(
        registration: registration,
        localFilePath: chunkFile.path,
        fileSizeBytes: fileContents.length,
      );

      expect(
        t.backend.s3Requests.map(
          (RecordedRequest r) => r.uri.queryParameters['partNumber'],
        ),
        <String>['1', '2'],
      );
    });

    test('progress is cumulative across the chunk, not per part', () async {
      // C-11 shows one percentage for the chunk; a per-part callback would
      // reset it to zero once per part.
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build(
        partCount: 3,
      );
      final ChunkRegistration registration = await register(t.api);

      final List<int> reported = <int>[];
      await t.api.uploadObject(
        registration: registration,
        localFilePath: chunkFile.path,
        fileSizeBytes: fileContents.length,
        onProgress: (int sent, int _) => reported.add(sent),
      );

      expect(reported, isNotEmpty);
      expect(reported.last, fileContents.length);
      // Never decreases.
      for (int i = 1; i < reported.length; i++) {
        expect(reported[i], greaterThanOrEqualTo(reported[i - 1]));
      }
    });

    test('a missing local file fails before any PUT', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      final ChunkRegistration registration = await register(t.api);

      await expectLater(
        t.api.uploadObject(
          registration: registration,
          localFilePath: '${tempDir.path}/does-not-exist.mp4',
          fileSizeBytes: 10,
        ),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.errorCode,
            'errorCode',
            ErrorCode.storageNotFound,
          ),
        ),
      );
      expect(t.backend.s3Requests, isEmpty);
    });

    test(
      'an already-completed cancel signal stops before the first part',
      () async {
        final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build(
          partCount: 3,
        );
        final ChunkRegistration registration = await register(t.api);

        await expectLater(
          t.api.uploadObject(
            registration: registration,
            localFilePath: chunkFile.path,
            fileSizeBytes: fileContents.length,
            cancelSignal: Future<void>.value(),
          ),
          throwsA(
            isA<NetworkException>().having(
              (NetworkException e) => e.errorCode,
              'errorCode',
              ErrorCode.networkCancelled,
            ),
          ),
        );
      },
    );

    test('an empty upload_urls list is refused', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();

      await expectLater(
        t.api.uploadObject(
          registration: const ChunkRegistration(
            chunkId: 'chk_1',
            s3ObjectKey: 'k',
            uploadUrls: <String>[],
          ),
          localFilePath: chunkFile.path,
          fileSizeBytes: fileContents.length,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('steps 3 and 4', () {
    test('the status PATCH hits /v1/chunks/{id}/status', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();

      await t.api.confirmStatus(chunkId: 'chk_1', status: 'complete');

      final RecordedRequest request = t.backend.backendRequests.last;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/v1/chunks/chk_1/status');
      expect(request.body, <String, Object?>{'status': 'complete'});
    });

    test('the PATCH is idempotent — a repeat is a plain success', () async {
      // Chapter 5.10 §3's claim, exercised rather than assumed.
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();

      await t.api.confirmStatus(chunkId: 'chk_1', status: 'complete');
      await t.api.confirmStatus(chunkId: 'chk_1', status: 'complete');

      expect(t.backend.backendRequests, hasLength(2));
    });

    test('the metadata POST sends the document unchanged', () async {
      final ({ChunkUploadApiImpl api, FakeBackendAdapter backend}) t = build();
      const Map<String, Object?> document = <String, Object?>{
        'chunk_id': 'chk_1',
        'identity': <String, Object?>{'session_id': 's'},
      };

      await t.api.postMetadata(chunkId: 'chk_1', document: document);

      final RecordedRequest request = t.backend.backendRequests.last;
      expect(request.uri.path, '/v1/chunks/chk_1/metadata');
      expect(request.body, document);
    });
  });
}

/// A token source with one fixed answer.
class _FixedTokenSource implements AuthTokenSource {
  _FixedTokenSource(this._token);

  final String? _token;

  @override
  Future<String?> currentToken() async => _token;

  @override
  Future<String?> refreshToken() async => _token;
}

/// A real logger at the quietest level, so the suite stays readable.
///
/// `AppLogger` is a concrete class rather than an interface, so this is the
/// real one — which is better anyway: it means `S3TransferClient`'s log calls
/// are genuinely executed rather than stubbed away, and a crash inside one
/// would fail a test rather than hide.
AppLogger _silentLogger() => AppLogger(environment: AppEnvironment.production);
