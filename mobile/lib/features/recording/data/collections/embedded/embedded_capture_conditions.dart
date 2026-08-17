import 'package:isar/isar.dart';

import 'package:mobile/features/recording/data/collections/embedded/embedded_gps_fix.dart';

part 'embedded_capture_conditions.g.dart';

/// The `capture_conditions` group on disk.
///
/// All three fields nullable, matching the domain type — Mission 3.6 chose
/// explicit absence over omission or zero-defaults, and the storage layer
/// preserves that rather than collapsing "not read" into a value.
@embedded
class EmbeddedCaptureConditions {
  /// Creates stored conditions.
  EmbeddedCaptureConditions();

  /// The fix, or null when location was unavailable or refused.
  EmbeddedGpsFix? gps;

  /// Charge percentage 0-100, or null when unavailable.
  int? batteryPercent;

  /// `wifi`, `cellular` or `none`, or null when unavailable.
  String? networkType;
}
