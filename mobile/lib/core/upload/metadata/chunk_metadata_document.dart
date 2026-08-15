import 'package:mobile/core/upload/metadata/metadata_capture_conditions_document.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_document.dart';
import 'package:mobile/core/upload/metadata/metadata_collector_authored_document.dart';
import 'package:mobile/core/upload/metadata/metadata_device_context_document.dart';
import 'package:mobile/core/upload/metadata/metadata_identity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_integrity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_timing_document.dart';

/// Volume 4 Chapter 4.5 §2's canonical metadata JSON, as a projection.
///
/// Chapter 5.10 §1 step 4 posts *"Ch.5.7's object, sent as-is"* to
/// `POST /v1/chunks/{id}/metadata`. This is the shape that goes on the wire.
///
/// ## Why a projection and not `ChunkMetadata`
///
/// `ChunkMetadata` lives in `features/recording/domain/`, and ADR-022 R3
/// forbids `features/upload/` importing it *"at any layer, in either
/// direction"*. Passing it through a `core/` contract would satisfy the import
/// checker while leaving the upload feature reading the recording feature's
/// schema — compliance without the property the rule protects, which is the
/// case ADR-040 already argued and rejected for `QueuedChunk`.
///
/// So `features/upload/` never sees `ChunkMetadata`. It sees this, and this
/// names no feature.
///
/// ## Why the groups are kept
///
/// Chapter 4.5 §2 notes the group names *"match the ones Volume 1, Chapter 1.3
/// already used, so there is no re-labeling between requirement and
/// implementation"*. `ChunkMetadata` preserves them for that reason and says
/// so; flattening them here would reintroduce the re-labelling one layer
/// further out, at the exact boundary where the shape has to be right.
///
/// ## Why `toJson` is written by hand
///
/// `json_serializable` is available and unused elsewhere in this project. It
/// is not used here because the wire names differ from the Dart names in three
/// places that a generator would need to be told about individually anyway —
/// `gps.lat`/`gps.lng` rather than latitude/longitude, `battery_pct` rather
/// than battery percent — and one field, `timing.duration_seconds`, is not
/// stored at all and has to be derived. A hand-written map is shorter than the
/// annotations describing those exceptions, and a test pins the whole document
/// against Chapter 4.5 §2's literal block so a drift fails rather than
/// silently reshapes the evidence.
class ChunkMetadataDocument {
  /// Creates the document.
  const ChunkMetadataDocument({
    required this.chunkId,
    required this.identity,
    required this.timing,
    required this.capture,
    required this.deviceContext,
    required this.captureConditions,
    required this.integrity,
    required this.collectorAuthored,
  });

  /// `chunk_id` — the only field outside a group.
  final String chunkId;

  /// `identity`. See [MetadataIdentityDocument] for why it is all nullable.
  final MetadataIdentityDocument identity;

  /// `timing`.
  final MetadataTimingDocument timing;

  /// `capture`.
  final MetadataCaptureDocument capture;

  /// `device_context`.
  final MetadataDeviceContextDocument deviceContext;

  /// `capture_conditions` — absent in full today, per A-062 §3.
  final MetadataCaptureConditionsDocument captureConditions;

  /// `integrity`.
  final MetadataIntegrityDocument integrity;

  /// `collector_authored` — the only group BR-22 permits changing later.
  final MetadataCollectorAuthoredDocument collectorAuthored;

  /// **A-068 Guard 1.** Whether the `identity` group names real things.
  ///
  /// The pipeline checks this before Chapter 5.10 §1 step 1 and refuses to
  /// register a chunk that fails it. Deliberately not `isComplete`: a missing
  /// `capture_conditions` makes a record less descriptive, while a missing
  /// `collector_id` makes it unattributable, and BR-22's immutability means
  /// unattributable is permanent.
  ///
  /// There is intentionally no `isComplete` here at all. It would be false for
  /// every chunk on grounds A-062 §3 has already deferred, so a caller reading
  /// it could only either ignore it or block every upload for a reason this
  /// mission was not asked to decide.
  bool get isIdentityComplete => identity.isComplete;

  /// Chapter 4.5 §2's shape, exactly.
  ///
  /// Key order follows the chapter. It carries no meaning to a JSON parser and
  /// is preserved so a reader can diff this against the specification line by
  /// line.
  Map<String, Object?> toJson() => <String, Object?>{
    'chunk_id': chunkId,
    'identity': identity.toJson(),
    'timing': timing.toJson(),
    'capture': capture.toJson(),
    'device_context': deviceContext.toJson(),
    'capture_conditions': captureConditions.toJson(),
    'integrity': integrity.toJson(),
    'collector_authored': collectorAuthored.toJson(),
  };

  @override
  String toString() =>
      'ChunkMetadataDocument($chunkId, '
      'identityComplete: $isIdentityComplete)';
}
