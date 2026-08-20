import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';
import 'package:mobile/features/recording/domain/entities/collector_authored.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/entities/metadata_device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';
import 'package:mobile/features/recording/domain/entities/metadata_timing.dart';

part 'chunk_metadata.freezed.dart';

/// Volume 4 Chapter 4.5's canonical metadata object, assembled on device.
///
/// Chapter 5.7 is *"The Mobile-Side Half of Volume 4's Metadata
/// Specification"* and defines no schema of its own — §2 names the sources
/// and Chapter 4.5 §2 fixes the shape. This is that shape.
///
/// ## The groups are types, not a flattened bag
///
/// Chapter 4.5 §2 notes that *"the field-group names above match the ones
/// Volume 1, Chapter 1.3 already used, so there is no re-labeling between
/// requirement and implementation"*. The grouping carries meaning across
/// three volumes, so flattening it here would be the re-labelling that
/// sentence exists to prevent.
///
/// [integrity] reuses Mission 3.4's `ChunkIntegrity` rather than restating
/// `file_size_bytes` and `checksum_sha256` — it is already exactly Chapter
/// 4.5's `integrity` group, produced by the chapter §2 says to take it from.
///
/// ## Generated once, never recomputed
///
/// Chapter 5.7 §4: *"if a chunk's upload fails and is retried, the exact same
/// metadata object is resent — it is never recomputed, since
/// capture_conditions like battery % and GPS are only meaningful as of the
/// actual capture moment"*. Nothing here derives a value at read time except
/// `MetadataTiming.durationSeconds`, which is a function of two stored
/// timestamps and cannot drift.
///
/// ## Persisted since Mission 3.7, and FR-META-09 is satisfied
///
/// Chapter 5.7 §3 requires it be written *"to the local Drift chunk_metadata
/// table … in the same transaction as the chunk's own local record"*. Amendment
/// A-062 recorded two problems: ADR-009 chose **Isar**, not Drift; and the
/// atomic pairing needed a storage layer that did not exist.
///
/// **Both are discharged.** `IsarChunkStore.saveChunk` writes the chunk row and
/// the metadata row inside one `writeTxn`, and moves the `.mp4` into place
/// before that transaction commits — so a committed row never names a file that
/// is not there. `LocalChunkMetadata` is the Isar collection, embedded rather
/// than flattened so the field shape still mirrors Chapter 4.5's JSON.
///
/// A-062's other three sections — the unsourced fields, the permission gap and
/// the GPS/NFR-META-01 conflict — remain open and are not touched by this.
@freezed
class ChunkMetadata with _$ChunkMetadata {
  /// Creates a metadata object.
  const factory ChunkMetadata({
    /// The chunk's stable UUID, minted at capture-stop (Mission 3.4.5).
    required String chunkId,
    required MetadataIdentity identity,
    required MetadataTiming timing,
    required MetadataCapture capture,
    required MetadataDeviceContext deviceContext,
    required MetadataCaptureConditions captureConditions,
    required ChunkIntegrity integrity,
    @Default(CollectorAuthored.empty) CollectorAuthored collectorAuthored,
  }) = _ChunkMetadata;

  const ChunkMetadata._();

  /// Whether every field Chapter 4.5 specifies actually carries a value.
  ///
  /// **False for anything this project produces today**, because
  /// `capture_conditions` has no source. Exposed so an incomplete object is
  /// detectable by a caller rather than only by inspection — the same reason
  /// [MetadataCaptureConditions.unavailable] is named rather than implied.
  bool get isComplete => captureConditions.isComplete && identity.isComplete;

  /// Whether the `identity` group names real things.
  ///
  /// Separate from [isComplete] because the two gaps close on different
  /// schedules and a consumer may care about only one. **Identity is the one
  /// that must gate upload**: Chapter 5.14 §1's S3 key is composed from these
  /// fields, so sending a chunk whose `collector_id` is
  /// [MetadataIdentity.unsourced] would write an object nobody can attribute.
  /// Missing `capture_conditions` merely makes a record less descriptive.
  bool get isIdentityComplete => identity.isComplete;
}
