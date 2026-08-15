import 'package:mobile/core/upload/metadata/chunk_metadata_document.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_conditions_document.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_document.dart';
import 'package:mobile/core/upload/metadata/metadata_collector_authored_document.dart';
import 'package:mobile/core/upload/metadata/metadata_device_context_document.dart';
import 'package:mobile/core/upload/metadata/metadata_identity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_integrity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_timing_document.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture_conditions.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_collector_authored.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_device_context.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_gps_fix.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_identity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_integrity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_timing.dart';
import 'package:mobile/features/recording/data/collections/local_chunk_metadata.dart';

/// Reads a stored metadata row back out as Chapter 4.5 §2's wire document.
///
/// ## The mapper `ChunkRecordMapper` deliberately did not write
///
/// That class states: *"There is no `fromLocal*`, and that is a decision …
/// Reading a `ChunkMetadata` back would have to supply a value for each
/// required field, and today those fields are stored **null** … A reverse
/// mapper written now would have to substitute empty strings, and an empty
/// `collector_id` that reached an upload would be indistinguishable from a
/// real one. The consumer that needs read-back is the Upload Queue, Chapter
/// 5.9, which is a later mission. It is left unwritten rather than written
/// wrong."*
///
/// **The hazard was real and it is answered, not overruled.** This does not
/// produce a `ChunkMetadata`. It produces a [ChunkMetadataDocument], whose
/// identity fields are nullable, so nothing is substituted anywhere in this
/// file: a stored null arrives as null, a stored blank arrives as blank, and
/// `ChunkMetadataDocument.isIdentityComplete` — A-068 Guard 1 — is what
/// refuses it before any network call. The narrowing that made the mapper
/// unsafe simply does not occur.
///
/// It lives in its own file rather than as a `ChunkRecordMapper` method
/// because that class documents itself as having no reverse direction, and a
/// static added underneath that paragraph would make its own documentation
/// false.
///
/// ## Why this compiles without `isar`
///
/// It names the `Embedded*` and `LocalChunkMetadata` types but never
/// `package:isar` itself — the same property `ChunkRecordMapper` already has,
/// and the reason ADR-039's confinement check stays green without naming a new
/// owner here.
///
/// ## Absence is preserved, never invented
///
/// A missing group produces a document group of nulls rather than a thrown
/// error or a substituted default. FR-META-09 makes a metadata row's existence
/// a guarantee, but the *contents* of its groups are exactly as incomplete as
/// A-062 says they are, and this is the boundary where that incompleteness
/// becomes visible to a consumer that can act on it.
abstract final class ChunkMetadataDocumentMapper {
  /// Builds the wire document from a stored row.
  static ChunkMetadataDocument fromLocal(LocalChunkMetadata row) {
    return ChunkMetadataDocument(
      chunkId: row.chunkId,
      identity: _identity(row.identity),
      timing: _timing(row.timing),
      capture: _capture(row.capture),
      deviceContext: _deviceContext(row.deviceContext),
      captureConditions: _captureConditions(row.captureConditions),
      integrity: _integrity(row.integrity),
      collectorAuthored: _collectorAuthored(row.collectorAuthored),
    );
  }

  static MetadataIdentityDocument _identity(EmbeddedIdentity? group) =>
      MetadataIdentityDocument(
        sessionId: group?.sessionId,
        projectId: group?.projectId,
        taskId: group?.taskId,
        collectorId: group?.collectorId,
        deviceId: group?.deviceId,
      );

  static MetadataTimingDocument _timing(EmbeddedTiming? group) =>
      MetadataTimingDocument(
        sequenceIndex: group?.sequenceIndex,
        startedAt: group?.startedAt,
        endedAt: group?.endedAt,
      );

  static MetadataCaptureDocument _capture(EmbeddedCapture? group) =>
      MetadataCaptureDocument(
        resolution: group?.resolution,
        frameRate: group?.frameRate,
        bitrateKbps: group?.bitrateKbps,
        codec: group?.codec,
        zoomFactor: group?.zoomFactor,
        camera: group?.camera,
      );

  static MetadataDeviceContextDocument _deviceContext(
    EmbeddedDeviceContext? group,
  ) => MetadataDeviceContextDocument(
    deviceModel: group?.deviceModel,
    osVersion: group?.osVersion,
    appVersion: group?.appVersion,
  );

  /// Unwraps the stored GPS object into two nullable coordinates.
  ///
  /// Isar cannot represent an absent embedded object, so `ChunkRecordMapper`
  /// writes a present `EmbeddedGpsFix` with both coordinates null when there
  /// is no fix. Reading it back, "the object exists" says nothing — only the
  /// coordinates do, and both being null is the absence.
  static MetadataCaptureConditionsDocument _captureConditions(
    EmbeddedCaptureConditions? group,
  ) {
    final EmbeddedGpsFix? fix = group?.gps;
    return MetadataCaptureConditionsDocument(
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      batteryPercent: group?.batteryPercent,
      networkType: group?.networkType,
    );
  }

  static MetadataIntegrityDocument _integrity(EmbeddedIntegrity? group) =>
      MetadataIntegrityDocument(
        fileSizeBytes: group?.byteCount,
        checksumSha256: group?.checksumSha256,
      );

  /// Copies the tag list rather than aliasing the stored one.
  ///
  /// The row is a mutable Isar object and the document is meant to be a stable
  /// snapshot of what will be sent; sharing the list would let a later write
  /// change a document already handed to the pipeline.
  static MetadataCollectorAuthoredDocument _collectorAuthored(
    EmbeddedCollectorAuthored? group,
  ) => MetadataCollectorAuthoredDocument(
    notes: group?.notes,
    tags: List<String>.of(group?.tags ?? const <String>[]),
  );
}
