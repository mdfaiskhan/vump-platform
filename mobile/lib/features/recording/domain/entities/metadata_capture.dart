import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_capture.freezed.dart';

/// The `capture` group of Volume 4 Chapter 4.5's metadata schema.
///
/// Fully sourced. Chapter 5.7 §2: *"the fixed parameters from Ch.5.2, plus the
/// zoom factor actually selected by Ch.5.1's capability ladder"* — so five of
/// the six come from `CameraSpecification` and the sixth from the session.
///
/// **`zoomFactor` is the measured verdict, not the specification's default.**
/// It is what the ladder resolved for this device and fixed for the session
/// (Ch. 5.2 §1), which on the one handset tested so far is 0.6 — the whole
/// reason Missions 3.1 and 3.1.6 exist.
@freezed
class MetadataCapture with _$MetadataCapture {
  /// Creates the capture group.
  const factory MetadataCapture({
    /// `"1920x1080"` — formatted from `CameraSpecification`'s two constants
    /// rather than written as a literal, so it cannot drift from them.
    required String resolution,

    /// From `CameraSpecification.frameRate`.
    required int frameRate,

    /// From `CameraSpecification.targetVideoBitrateKbps`.
    required int bitrateKbps,

    /// The **wire** spelling, `"h264"` — see `CodecWireName` for why this
    /// differs from `CameraSpecification.videoCodec`'s `'H.264'`.
    required String codec,

    /// From `RecordingSession.zoomFactor` — the ladder's verdict.
    required double zoomFactor,

    /// `"rear-wide"`. BR-01 fixes the camera and BR-02 the field of view, so
    /// this is constant for every chunk this application will ever produce.
    required String camera,
  }) = _MetadataCapture;
}
