import 'package:flutter/services.dart';

import 'package:mobile/features/recording/domain/repositories/thermal_state_reader.dart';

/// Reads the thermal status over the project's third platform channel.
///
/// Confined the way `FreeSpaceChannel` is, and for the same reasons: one file
/// owns the channel, nothing platform-specific leaves it, and the only type
/// crossing the boundary is an `int?` out. Volume 3 Chapter 3.1 already
/// sanctions the pattern by name.
///
/// ## Why a channel rather than a package
///
/// No admitted package exposes thermal status, and `battery_plus` — which this
/// project already carries — does not either. A new dependency would carry
/// ADR-030's full admission for what is, on the native side, a single call.
///
/// ## Every failure resolves to null, deliberately
///
/// Unlike `FreeSpaceChannel`, which throws a `StorageException` because a
/// pipeline that cannot measure free space must stop, **nothing here is worth
/// failing a chunk over.** The footage is complete and correct; one optional
/// field is missing. Migration 0017's column is nullable precisely so this can
/// be recorded rather than escalated.
///
/// So all three absences collapse to the same answer:
///
/// - the platform returned null (API below 29, or no `PowerManager`)
/// - the channel raised a `PlatformException`
/// - the native half is not registered (`MissingPluginException`)
///
/// **The last one is a packaging fault rather than a device limitation**, and
/// it is the one that would be masked by this. It is accepted because the
/// alternative — failing finalization on a build that forgot to register a
/// channel — turns a missing field into lost footage. Anything that needs to
/// distinguish them can read [ThermalStateReader]'s contract and check whether
/// the field is null across every chunk rather than one.
class ThermalChannel implements ThermalStateReader {
  /// Creates a reader over the platform channel, or over a fake one in tests.
  const ThermalChannel({this._channel = _defaultChannel});

  static const MethodChannel _defaultChannel = MethodChannel('vump/thermal');

  final MethodChannel _channel;

  @override
  Future<int?> currentThermalState() async {
    try {
      return await _channel.invokeMethod<int>('currentThermalStatus');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
