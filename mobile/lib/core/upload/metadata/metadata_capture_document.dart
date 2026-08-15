/// The `capture` group of Volume 4 Chapter 4.5 §2's wire shape.
///
/// BR-01/BR-02's fixed specification as it was actually applied to this chunk,
/// not as it was requested — Chapter 5.7 §4 requires the object be resent
/// unchanged on every retry, so these are a record of what happened.
class MetadataCaptureDocument {
  /// Creates the capture group.
  const MetadataCaptureDocument({
    this.resolution,
    this.frameRate,
    this.bitrateKbps,
    this.codec,
    this.zoomFactor,
    this.camera,
  });

  /// `capture.resolution`, e.g. `1920x1080`.
  final String? resolution;

  /// `capture.frame_rate`.
  final int? frameRate;

  /// `capture.bitrate_kbps`.
  final int? bitrateKbps;

  /// `capture.codec`, e.g. `h264`.
  final String? codec;

  /// `capture.zoom_factor`, e.g. `0.6`.
  ///
  /// Normalised at the data boundary since Mission 3.1.6 — a Java `float`
  /// widens to a Dart `double` as `0.6000000238418579`, and the raw value
  /// would put that on the wire as evidence.
  final double? zoomFactor;

  /// `capture.camera`, e.g. `rear-wide`.
  final String? camera;

  /// Chapter 4.5 §2's `capture` object.
  Map<String, Object?> toJson() => <String, Object?>{
    'resolution': resolution,
    'frame_rate': frameRate,
    'bitrate_kbps': bitrateKbps,
    'codec': codec,
    'zoom_factor': zoomFactor,
    'camera': camera,
  };
}
