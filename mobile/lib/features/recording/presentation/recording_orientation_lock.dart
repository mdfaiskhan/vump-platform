import 'package:flutter/services.dart';

/// Holds the landscape lock across the whole recording flow.
///
/// ADR-054 decision 4 and its third amendment. Two screens need landscape —
/// the Checklist and the Recording screen — and the Collector moves from one
/// to the other without passing through anything portrait.
///
/// ## Why a counter rather than set-on-enter, restore-on-exit
///
/// **Flutter builds the incoming route before disposing the outgoing one.** A
/// screen that restored portrait in `dispose` would therefore undo the
/// landscape its successor had *already* requested, and the window would drop
/// back to portrait in the middle of the flow — precisely the stale-rotation
/// window this record exists to remove.
///
/// Counting makes the order irrelevant. The Checklist acquires (0 → 1,
/// landscape), the Recording screen acquires (1 → 2, no change), the Checklist
/// releases late (2 → 1, still landscape), and portrait returns only when the
/// last holder lets go.
///
/// ## Why the lock's TIMING is load-bearing
///
/// `camera_android_camerax` reads the display rotation **once, when the camera
/// is created** — `_initialDefaultDisplayRotation` at
/// `android_camera_camerax.dart:433` — and refreshes it only from the
/// accelerometer stream. `DeviceOrientationManager.start()` registers an
/// `OrientationEventListener` and nothing else, so a window rotated by
/// `SystemChrome` while the handset lies still refreshes nothing.
///
/// So the window must already be in its final orientation **before**
/// `openSession` creates the camera. `openSession` runs from the Checklist's
/// Start action, which is why the lock is acquired there rather than on the
/// Recording screen — by the time that screen mounts, the camera has already
/// baked in whatever the window was.
///
/// ## Landscape is the two landscape orientations, never portrait
///
/// Flutter maps all four orientations to `SCREEN_ORIENTATION_FULL_USER`, which
/// **respects the handset's auto-rotate setting** — so permitting all four
/// would fail to rotate at all on a device with auto-rotate off. The two
/// landscape values map to `SCREEN_ORIENTATION_USER_LANDSCAPE`, which forces
/// landscape regardless.
abstract final class RecordingOrientationLock {
  static int _holders = 0;

  /// The orientations the recording flow runs in.
  static const List<DeviceOrientation> landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// What every other route runs in.
  static const List<DeviceOrientation> portrait = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  /// How many screens currently hold the lock. Visible for tests.
  static int get holders => _holders;

  /// Takes the lock, rotating to landscape if this is the first holder.
  static Future<void> acquire() async {
    _holders += 1;
    if (_holders == 1) {
      await SystemChrome.setPreferredOrientations(landscape);
    }
  }

  /// Gives the lock back, restoring portrait when the last holder releases.
  static Future<void> release() async {
    if (_holders == 0) {
      return;
    }
    _holders -= 1;
    if (_holders == 0) {
      await SystemChrome.setPreferredOrientations(portrait);
    }
  }

  /// Drops every holder and restores portrait. For test isolation only.
  static Future<void> resetForTest() async {
    _holders = 0;
    await SystemChrome.setPreferredOrientations(portrait);
  }
}
