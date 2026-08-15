import 'package:isar/isar.dart';

part 'embedded_integrity.g.dart';

/// The `integrity` group on disk — Mission 3.4's checksum and byte count.
///
/// Duplicated onto `LocalChunk` as well, because Volume 4's `chunks` table
/// carries `checksum_sha256` and `file_size_bytes` in its own right and the
/// Upload Queue reads them there without loading metadata.
@embedded
class EmbeddedIntegrity {
  /// Creates a stored EmbeddedIntegrity.
  EmbeddedIntegrity();

  /// Lowercase hex SHA-256 of the finalized file (Ch. 5.5 §1.2).
  String? checksumSha256;

  /// The file's size in bytes, read from the closed handle (§1.3).
  int? byteCount;
}
