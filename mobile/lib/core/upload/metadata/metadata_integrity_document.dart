/// The `integrity` group of Volume 4 Chapter 4.5 §2's wire shape.
///
/// The one group that is complete and correct for every chunk this
/// application has ever produced. Chapter 4.5 §3 step 3 makes it load-bearing:
/// the backend *"independently verifies `integrity.checksum_sha256` against
/// the actual uploaded S3 object … before setting `chunk_metadata.verified_at`
/// and allowing `chunks.status` → `complete`"* (FR-META-12, BR-21).
class MetadataIntegrityDocument {
  /// Creates the integrity group.
  const MetadataIntegrityDocument({this.fileSizeBytes, this.checksumSha256});

  /// `integrity.file_size_bytes`.
  final int? fileSizeBytes;

  /// `integrity.checksum_sha256`, computed off the UI isolate at finalization.
  ///
  /// Never recomputed. Chapter 5.7 §4 requires the identical object on every
  /// retry, and a checksum recomputed after the fact would verify the file as
  /// it is now rather than as it was when it was sealed.
  final String? checksumSha256;

  /// Chapter 4.5 §2's `integrity` object.
  Map<String, Object?> toJson() => <String, Object?>{
    'file_size_bytes': fileSizeBytes,
    'checksum_sha256': checksumSha256,
  };
}
