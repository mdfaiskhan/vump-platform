import 'package:isar/isar.dart';

part 'embedded_capture.g.dart';

/// The `capture` group on disk.
///
/// `codec` holds the **wire** spelling (`h264`), not `CameraSpecification`'s
/// `H.264` — the stored row is what the backend will receive, so translating
/// on write rather than on upload keeps one spelling in the database.
@embedded
class EmbeddedCapture {
  /// Creates a stored EmbeddedCapture.
  EmbeddedCapture();

  /// Formatted `WIDTHxHEIGHT`, from `CameraSpecification`.
  String? resolution;

  /// Frames per second — 30, per Chapter 5.2 §1.
  int? frameRate;

  /// Target video bitrate in kbps — 8,000, per Chapter 5.2 §1.
  int? bitrateKbps;

  /// The **wire** spelling, `h264` — see `CodecWireName`.
  String? codec;

  /// The ladder's resolved factor for this session — 0.5 or 0.6.
  double? zoomFactor;

  /// `rear-wide`, fixed by BR-01 and BR-02.
  String? camera;
}
