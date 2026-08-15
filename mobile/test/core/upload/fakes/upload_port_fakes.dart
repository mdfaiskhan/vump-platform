/// In-memory stand-ins for Mission 4.2's three `core/upload/` ports.
///
/// Tier 2 of the two-tier fake. These test the pipeline's **step sequencing**
/// — Guard 1's position, which status is written on which path, whether a
/// cancellation releases rather than fails — with no transport at all.
///
/// Tier 1 (`FakeBackendAdapter`) does the opposite: it keeps every real client
/// and fakes only the socket, so the request bodies and envelope parsing are
/// genuinely exercised. Neither substitutes for the other.
library;

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/core/errors/exceptions/validation_exception.dart';
import 'package:mobile/core/upload/interfaces/chunk_metadata_source.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/interfaces/session_registrar.dart';
import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';

/// A claimable queue held in a list.
class FakeChunkUploadSource implements ChunkUploadSource {
  /// Creates a source over [queued], claimed in the order given.
  FakeChunkUploadSource({List<UploadableChunk>? queued})
    : _queued = <UploadableChunk>[...?queued];

  final List<UploadableChunk> _queued;

  /// Every transition asked for, in order — `'claim:id'`, `'failed:id'`, and
  /// so on.
  ///
  /// Recorded as a sequence rather than as flags so a test can assert that
  /// `complete` was written **after** the metadata POST (A-073) and not merely
  /// that it was written.
  final List<String> transitions = <String>[];

  /// Object keys recorded, by chunk id.
  final Map<String, String> objectKeys = <String, String>{};

  /// Set to make [claimNext] throw, for the storage-failure path.
  bool failOnClaim = false;

  @override
  Future<UploadableChunk?> claimNext() async {
    if (failOnClaim) {
      throw const StorageException(
        errorCode: ErrorCode.storageReadFailed,
        message: 'scripted',
      );
    }
    if (_queued.isEmpty) {
      return null;
    }
    final UploadableChunk chunk = _queued.removeAt(0);
    transitions.add('claim:${chunk.chunkId}');
    return chunk;
  }

  @override
  Future<void> recordObjectKey({
    required String chunkId,
    required String s3ObjectKey,
  }) async {
    objectKeys[chunkId] = s3ObjectKey;
    transitions.add('key:$chunkId');
  }

  @override
  Future<void> release(String chunkId) async =>
      transitions.add('released:$chunkId');

  @override
  Future<void> markFailed(String chunkId) async =>
      transitions.add('failed:$chunkId');

  @override
  Future<void> markComplete(String chunkId) async =>
      transitions.add('complete:$chunkId');
}

/// A metadata source over a map.
class FakeChunkMetadataSource implements ChunkMetadataSource {
  /// Creates a source over [documents], keyed by chunk id.
  FakeChunkMetadataSource({Map<String, ChunkMetadataDocument>? documents})
    : _documents = <String, ChunkMetadataDocument>{...?documents};

  final Map<String, ChunkMetadataDocument> _documents;

  /// Set to make [metadataDocument] throw.
  bool failOnRead = false;

  @override
  Future<ChunkMetadataDocument?> metadataDocument(String chunkId) async {
    if (failOnRead) {
      throw const StorageException(
        errorCode: ErrorCode.storageReadFailed,
        message: 'scripted metadata read failure',
      );
    }
    return _documents[chunkId];
  }
}

/// A registrar that answers with a fixed id, or refuses.
///
/// **The only implementation of `SessionRegistrar` that exists anywhere.**
/// Nothing in `lib/` satisfies that port: it needs a `task_id`, and
/// `features/projects_tasks/` is unbuilt. This is what lets Chapter 5.10's
/// pipeline be tested end to end regardless.
class FakeSessionRegistrar implements SessionRegistrar {
  /// Creates a registrar answering with [sessionId].
  FakeSessionRegistrar({this.sessionId = 'srv_sess_1'});

  /// What [remoteSessionId] answers with.
  final String sessionId;

  /// Set to refuse, as the real implementation must when a session has no
  /// Task — Chapter 5.13 §1's terminal, device-side class.
  bool hasNoTask = false;

  /// The local session ids asked about.
  final List<String> asked = <String>[];

  @override
  Future<String> remoteSessionId(String localSessionId) async {
    asked.add(localSessionId);
    if (hasNoTask) {
      throw const ValidationException(
        errorCode: ErrorCode.validationRequiredField,
        message: 'The session has no task_id to register under.',
        field: 'task_id',
      );
    }
    return sessionId;
  }
}
