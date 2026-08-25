/// What the Recording Screen needs to draw a live preview, and nothing more.
///
/// ADR-053's seam, in one value. FR-REC-03 requires a full-screen live preview
/// during recording; A-064 §5 recorded why there was none, and this is the
/// shape chosen to close it.
///
/// ## Three numbers, deliberately
///
/// `CameraPreview` looks like it needs a `CameraController`. It does not — it
/// reduces to `buildPreview()`, which takes a texture id and nothing else, an
/// immutable `CameraValue` read for shape and orientation, and a change
/// signal. So a preview needs a texture id, an aspect ratio and a rotation.
///
/// **None of those is a capability.** Mission 3.3 kept the controller private
/// so the UI could not start or stop capture behind `RecordingNotifier`'s
/// state machine, and that property survives here by *type* rather than by
/// discipline: an `int` has no `startVideoRecording` to call.
///
/// ## Pure Dart, and that is the point
///
/// No `Widget`, no `Listenable`, no `CameraValue`, no `DeviceOrientation`.
/// `domain/` is pure Dart and ADR-026 lists that purity among the invariants
/// only review enforces — the kind that erodes quietly. Returning a built
/// preview `Widget` from the port would have been far less code and would have
/// spent it.
///
/// ## [aspectRatio] is the camera's NATIVE ratio; the flip belongs elsewhere
///
/// It was orientation-corrected here until 2026-08-25. `CameraPreview` flips
/// the controller's raw ratio for portrait, and reproducing that flip in
/// `data/` looked like the tidy choice — the plugin type it needs already
/// lives there, and a consumer could apply the finished number without
/// learning which way up the device is.
///
/// **It was the wrong place, and ADR-053's fourth amendment records why.**
/// The flip answers *"what shape should this box be"*, which is a fact about
/// the **window**, and the pipeline has no `BuildContext` with which to know
/// one. It flipped on `deviceOrientation` instead — a value the platform
/// updates **only when the accelerometer fires** — so a window rotated by
/// `SystemChrome` while the handset lay still kept a portrait ratio in a
/// landscape window, and the preview stretched.
///
/// The consumer now flips it from `MediaQuery`, which is the authority on
/// window orientation and needs no sensor. The seam still carries three
/// primitives and no capability; one of them simply describes the camera now
/// rather than the layout.
final class PreviewFrame {
  /// Creates a frame description.
  const PreviewFrame({
    required this.textureId,
    required this.aspectRatio,
    required this.quarterTurns,
  });

  /// The platform texture the preview draws, from `CameraController.cameraId`.
  final int textureId;

  /// Width over height of the camera's **native** output — orientation NOT
  /// applied, and deliberately so.
  final double aspectRatio;

  /// Clockwise quarter-turns to rotate the texture by, 0–3.
  ///
  /// Android delivers the texture in the sensor's orientation; the rotation
  /// `CameraPreview` applies is reproduced behind this seam. Always 0 where
  /// the platform needs no correction.
  final int quarterTurns;

  @override
  bool operator ==(Object other) =>
      other is PreviewFrame &&
      other.textureId == textureId &&
      other.aspectRatio == aspectRatio &&
      other.quarterTurns == quarterTurns;

  @override
  int get hashCode => Object.hash(textureId, aspectRatio, quarterTurns);

  @override
  String toString() =>
      'PreviewFrame($textureId, ${aspectRatio.toStringAsFixed(3)}, '
      '${quarterTurns}q)';
}
