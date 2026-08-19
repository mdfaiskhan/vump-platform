/// Reads the OS-reported device model — F22.
///
/// ## Why a channel and not `device_info_plus`
///
/// `FreeSpaceChannel` established the precedent and the reasoning transfers
/// almost unchanged: a package would carry ADR-030's full admission — a
/// confinement entry, an inventory row, a conversion boundary — for a handful
/// of lines of platform code that read two constants.
///
/// `device_info_plus` is also considerably more than this needs. It surfaces
/// dozens of fields across both platforms; Volume 4 Chapter 4.4 §7 wants one
/// string. Admitting a broad dependency to read `Build.MODEL` would be the
/// opposite of ADR-030's stated posture.
///
/// ## What it returns
///
/// `manufacturer model` where both are known — *"OnePlus CPH2707"* rather than
/// the bare *"CPH2707"* the device reports on its own, because a model code
/// without its maker is not identifiable by a reader of A-08's metadata screen.
///
/// ## Failure is absence, not an exception
///
/// Unlike `FreeSpaceChannel`, a failed read here is **not** thrown. Free space
/// gates whether recording may start, so an unanswerable question must stop
/// the flow; a device model is descriptive metadata. Throwing would fail a
/// chunk over a label.
///
/// It returns `null` instead, and the composition root decides. That decision
/// is not "substitute something" — the backend requires `device_model` to be
/// non-empty, so a null here surfaces as a refused metadata POST rather than
/// as an invented value silently attached to real footage.
library;

import 'package:flutter/services.dart';

/// Reads the device model over the platform channel.
class DeviceModelChannel {
  /// Creates a reader over the platform channel, or over a fake one in tests.
  const DeviceModelChannel({this._channel = _defaultChannel});

  static const MethodChannel _defaultChannel = MethodChannel(
    'vump/device_model',
  );

  final MethodChannel _channel;

  /// The OS-reported model, or `null` when the platform cannot answer.
  Future<String?> read() async {
    try {
      final String? model = await _channel.invokeMethod<String>('deviceModel');
      if (model == null || model.trim().isEmpty) {
        return null;
      }
      return model.trim();
    } on PlatformException {
      // Descriptive metadata, not a gate. See the class comment.
      return null;
    } on MissingPluginException {
      // The channel is unregistered — a test host, or a platform with no
      // implementation. Absence rather than a crash, for the same reason.
      return null;
    }
  }
}
