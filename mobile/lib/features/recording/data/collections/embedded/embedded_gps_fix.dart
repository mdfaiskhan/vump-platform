import 'package:isar/isar.dart';

part 'embedded_gps_fix.g.dart';

/// `capture_conditions.gps` on disk.
///
/// Both coordinates nullable together: Isar has no notion of "this whole
/// object is absent", so a chunk recorded without location permission stores
/// an EmbeddedGpsFix whose fields are null, and the mapper reads that back as
/// a null `GpsFix` rather than a fix at (0, 0).
@embedded
class EmbeddedGpsFix {
  /// Creates a stored EmbeddedGpsFix.
  EmbeddedGpsFix();

  /// Degrees north. Null together with [longitude] when unavailable.
  double? latitude;

  /// Degrees east. Null together with [latitude] when unavailable.
  double? longitude;
}
