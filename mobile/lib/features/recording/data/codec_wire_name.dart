import 'package:mobile/features/recording/domain/entities/camera_specification.dart';

/// Translates the codec name between the two spellings the volumes use.
///
/// Volume 5 Chapter 5.2 §1's capture table writes it **`H.264 (AVC)`**, and
/// `CameraSpecification.videoCodec` transcribes that as `'H.264'`. Volume 4
/// Chapter 4.5 §2's wire format writes it **`"codec": "h264"`**.
///
/// Both are correct for their own side: 5.2 is describing an encoder to a
/// reader, 4.5 is fixing a JSON value a backend parses. Changing either to
/// match the other would make one of them wrong, so the difference is
/// translated at the boundary instead — which is where the two meet and the
/// only place that knows both.
///
/// Small enough not to need an amendment, and recorded here rather than
/// inline at the call site so the next person to notice the mismatch finds
/// the reason attached to it.
abstract final class CodecWireName {
  /// The `capture.codec` value Chapter 4.5 expects.
  static const String h264 = 'h264';

  /// Maps a `CameraSpecification` codec name to its wire spelling.
  ///
  /// Unknown values pass through lowercased rather than throwing: the wire
  /// format is a string field, and a codec this project does not yet produce
  /// is a reason to send what was actually used, not to fail assembly.
  static String forSpecification(String specificationName) {
    return specificationName == CameraSpecification.videoCodec
        ? h264
        : specificationName.toLowerCase().replaceAll('.', '');
  }
}
