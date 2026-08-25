/// Two metadata documents, and the difference between them is the whole point.
///
/// A-068 Guard 1 has to be tested against both a chunk that may be sent and a
/// chunk that must not be, and *"must not be"* is the state every chunk this
/// application has actually recorded is in. Building only the happy case would
/// test the guard's plumbing and never its verdict.
library;

import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_conditions_document.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_document.dart';
import 'package:mobile/core/upload/metadata/metadata_collector_authored_document.dart';
import 'package:mobile/core/upload/metadata/metadata_device_context_document.dart';
import 'package:mobile/core/upload/metadata/metadata_identity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_integrity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_timing_document.dart';

/// A document whose `identity` group names real things.
///
/// **Synthetic.** Nothing on a device produces this today: `project_id`,
/// `task_id`, `collector_id` and `device_id` all carry
/// `MetadataIdentity.unsourced` until `features/projects_tasks/`, the
/// `collector_id` inversion and a `device_id` source exist. It exists so the
/// four steps beyond the guard can be exercised at all.
ChunkMetadataDocument completeIdentityDocument({String chunkId = 'chk_1'}) =>
    ChunkMetadataDocument(
      chunkId: chunkId,
      identity: const MetadataIdentityDocument(
        sessionId: 'sess_e810',
        projectId: 'proj_4a1',
        taskId: 'task_7c3',
        collectorId: 'user_22b',
        deviceId: 'dev_5f0',
      ),
      timing: MetadataTimingDocument(
        sequenceIndex: 3,
        startedAt: DateTime.utc(2026, 8, 15, 9),
        endedAt: DateTime.utc(2026, 8, 15, 9, 10),
      ),
      capture: const MetadataCaptureDocument(
        resolution: '1920x1080',
        frameRate: 30,
        bitrateKbps: 8000,
        codec: 'h264',
        zoomFactor: 0.6,
        camera: 'rear-wide',
        // Migration 0017. ADR-054's device-verified constant.
        orientation: 'landscape-left',
      ),
      deviceContext: const MetadataDeviceContextDocument(
        deviceModel: 'Pixel 6a',
        osVersion: 'Android 15',
        appVersion: '1.0.0+1',
      ),
      captureConditions: const MetadataCaptureConditionsDocument(),
      integrity: const MetadataIntegrityDocument(
        fileSizeBytes: 512000000,
        checksumSha256: 'abc123',
      ),
      collectorAuthored: const MetadataCollectorAuthoredDocument(),
    );

/// A document shaped exactly as a real recorded chunk's is today.
///
/// `session_id` is the only identity field with a source. The other four carry
/// the empty-string sentinel `MetadataIdentity.unsourced`, which is what
/// `ChunkRecordMapper` actually writes — not null, and that distinction is why
/// `isComplete` tests for blank as well as absent.
ChunkMetadataDocument unsourcedIdentityDocument({String chunkId = 'chk_1'}) =>
    ChunkMetadataDocument(
      chunkId: chunkId,
      // The sentinel, verbatim: MetadataIdentity.unsourced is ''.
      identity: const MetadataIdentityDocument(
        sessionId: 'sess_e810',
        projectId: '',
        taskId: '',
        collectorId: '',
        deviceId: '',
      ),
      timing: MetadataTimingDocument(
        sequenceIndex: 3,
        startedAt: DateTime.utc(2026, 8, 15, 9),
        endedAt: DateTime.utc(2026, 8, 15, 9, 10),
      ),
      capture: const MetadataCaptureDocument(
        resolution: '1920x1080',
        frameRate: 30,
        bitrateKbps: 8000,
        codec: 'h264',
        zoomFactor: 0.6,
        camera: 'rear-wide',
      ),
      deviceContext: const MetadataDeviceContextDocument(
        deviceModel: 'Pixel 6a',
        osVersion: 'Android 15',
        appVersion: '1.0.0+1',
      ),
      captureConditions: const MetadataCaptureConditionsDocument(),
      integrity: const MetadataIntegrityDocument(
        fileSizeBytes: 512000000,
        checksumSha256: 'abc123',
      ),
      collectorAuthored: const MetadataCollectorAuthoredDocument(),
    );
