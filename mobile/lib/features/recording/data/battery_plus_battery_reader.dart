import 'package:battery_plus/battery_plus.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/domain/repositories/battery_reader.dart';

/// Reads FR-CHK-03's charge level through `battery_plus`.
///
/// Named for the package it binds, following
/// `SharedPreferencesWideAngleEligibilityCache` and `CameraRecordingPipeline`
/// — the file announces what it depends on, and ADR-039 made that naming
/// load-bearing for `isar`.
///
/// ## A single reading, not a subscription
///
/// Volume 2 Chapter 2.7's C-07 requires the Checklist to *"re-evaluate live if
/// a value changes (e.g. battery drains) while the screen is open"*, which
/// sounds like a stream. It is driven by re-reading instead, for the same
/// reason `RecordingNotifier` polls free space rather than watching it: the
/// checklist has four other rows that have no stream at all, and one
/// re-measurement path for all five is simpler than one row updating on a
/// different mechanism from its neighbours.
class BatteryPlusBatteryReader implements BatteryReader {
  /// Creates a reader over [battery], or the plugin's own singleton.
  BatteryPlusBatteryReader({Battery? battery})
    : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<int> percent() async {
    try {
      return await _battery.batteryLevel;
    } on Object catch (error, stackTrace) {
      // `battery_plus` throws a PlatformException on some devices and a bare
      // `Exception` on others; neither is a type this layer should name.
      // ADR-025 §7 requires the conversion happen here, at the module that
      // owns the package, whatever shape it arrives in.
      throw DeviceException(
        errorCode: ErrorCode.deviceBatteryUnreadable,
        message: 'The battery level could not be read.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
