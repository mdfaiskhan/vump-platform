import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/repositories/capture_conditions_reader.dart';

/// Reports that no capture condition was read — explicitly, every time.
///
/// ## Two of the three are now reachable, and are still not read
///
/// Mission 3.8 admitted `battery_plus` and `connectivity_plus` for the
/// Checklist, so battery percentage and network type could be filled in here
/// today with two lines. They are not, deliberately.
///
/// Volume 5 Chapter 5.7 §2 requires these be read *"at the moment of chunk
/// finalization, not session start"*, and amendment A-062 §3 records that the
/// clause **conflicts with NFR-META-01** for the third field: a cold GPS fix
/// takes seconds against a 500 ms budget. That conflict is escalated and
/// unresolved, and its resolution decides the shape of this whole group —
/// whether it is awaited, cached, or moved off the hot path. Filling in two
/// fields under one reading of a rule that is still being decided would make
/// the group half-committed to an answer nobody has given.
///
/// So the group stays uniformly absent until A-062 §3 is resolved, which is
/// also when the third field becomes answerable. Recorded in A-064.
///
/// ## Absence is explicit, never a default
///
/// [MetadataCaptureConditions.unavailable] carries three nulls rather than
/// omitting the group or zero-filling it — `{0.0, 0.0}` is a real place in the
/// Gulf of Guinea, and a plausible wrong value is harder to catch than an
/// obviously empty one.
class UnavailableCaptureConditionsReader implements CaptureConditionsReader {
  /// Creates the reader.
  const UnavailableCaptureConditionsReader();

  @override
  Future<MetadataCaptureConditions> read() async =>
      MetadataCaptureConditions.unavailable;
}
