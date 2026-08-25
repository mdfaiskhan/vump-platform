import 'package:flutter/services.dart' show DeviceOrientation;

/// Wire spellings for `capture.orientation`, migration 0017.
///
/// The same job `CodecWireName` does for `H.264` → `h264`: the plugin's enum
/// stays inside `data/`, and what crosses the wire and lands in
/// `chunk_metadata.capture_orientation` is a lowercase, hyphenated string that
/// a dataset consumer can read without knowing Flutter exists.
///
/// ## Why not store the enum's `name`
///
/// `DeviceOrientation.landscapeLeft.name` is `landscapeLeft`. That spelling
/// leaks a Dart identifier convention into a database column, and — more to the
/// point — it would change silently if the plugin ever renamed a value. These
/// four constants are this project's, and a plugin rename becomes a compile
/// error in [of] rather than a quiet change in the data.
abstract final class CaptureOrientationWireName {
  /// The handset upright.
  static const String portraitUp = 'portrait-up';

  /// The handset upside-down.
  static const String portraitDown = 'portrait-down';

  /// The orientation ADR-054 locks capture to, device-verified 2026-08-25.
  static const String landscapeLeft = 'landscape-left';

  /// The other landscape. ADR-054's amendment records that locking to this one
  /// produced a 180° rotation tag — upside-down footage — on a CPH2707.
  static const String landscapeRight = 'landscape-right';

  /// The wire spelling for [orientation].
  static String of(DeviceOrientation orientation) {
    return switch (orientation) {
      DeviceOrientation.portraitUp => portraitUp,
      DeviceOrientation.portraitDown => portraitDown,
      DeviceOrientation.landscapeLeft => landscapeLeft,
      DeviceOrientation.landscapeRight => landscapeRight,
    };
  }
}
