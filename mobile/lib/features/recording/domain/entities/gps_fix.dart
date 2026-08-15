import 'package:freezed_annotation/freezed_annotation.dart';

part 'gps_fix.freezed.dart';

/// A latitude/longitude pair, as Volume 4 Chapter 4.5's `capture_conditions`
/// nests it.
///
/// Separate from `MetadataCaptureConditions` because the whole fix is absent
/// or present together — a chunk recorded without location permission has no
/// latitude *and* no longitude, and modelling them as two independent
/// nullables would permit a half-fix that means nothing.
@freezed
class GpsFix with _$GpsFix {
  /// Creates a fix.
  const factory GpsFix({required double latitude, required double longitude}) =
      _GpsFix;
}
