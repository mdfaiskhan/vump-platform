import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/repositories/capture_conditions_reader.dart';
import 'package:mobile/features/recording/domain/repositories/thermal_state_reader.dart';

/// Reads the one capture condition this project can currently source.
///
/// Replaces `UnavailableCaptureConditionsReader` in the composition root.
/// Migration 0017.
///
/// ## Why the name says "thermal" and not "platform"
///
/// It reads thermal status and nothing else. **GPS, battery percentage and
/// network type are all still null**, and calling this a general conditions
/// reader would imply otherwise to the next person wiring it.
///
/// - **GPS is blocked on a spec conflict, not on effort.** Chapter 5.7 §2 wants
///   the fix *at* finalization; NFR-META-01 caps metadata generation at 500 ms;
///   a cold fix takes seconds. Amendment A-062 records that as needing a
///   product decision — await, cache, or drop — and it is **not** taken here.
/// - **Battery and network are a different story, and worth flagging.**
///   `BatteryPlusBatteryReader` and `ConnectivityPlusNetworkReader` both exist
///   in this same directory and are already wired — to the Checklist, not to
///   metadata. Sourcing them here is plausibly a small change and was **out of
///   scope for the mission that added thermal**. It is named rather than done,
///   so the next reader finds a decision rather than an oversight.
///
/// ## Nothing here can fail a chunk
///
/// [ThermalStateReader]'s contract is that it returns null rather than throws,
/// so this cannot raise. A chunk whose footage is complete must not be lost
/// because an optional field could not be read.
class ThermalCaptureConditionsReader implements CaptureConditionsReader {
  /// Creates a reader over the thermal port.
  const ThermalCaptureConditionsReader({
    required ThermalStateReader thermalReader,
  }) : _thermal = thermalReader;

  final ThermalStateReader _thermal;

  @override
  Future<MetadataCaptureConditions> read() async {
    return MetadataCaptureConditions(
      thermalState: await _thermal.currentThermalState(),
    );
  }
}
