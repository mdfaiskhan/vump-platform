import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';

/// Volume 5.2 §1's table, asserted value by value.
///
/// A test that only reads the constants back would pass against any numbers
/// at all. These assert the **literals from the chapter**, so a change to a
/// capture parameter has to be a deliberate edit here as well as there — which
/// is the point, because Chapter 5.2 calls itself the authoritative source and
/// Volume 4 Chapter 4.5's metadata block quotes these same figures.
void main() {
  group('fixed capture parameters — Volume 5.2 §1', () {
    test('resolution is 1920x1080', () {
      expect(CameraSpecification.widthPixels, 1920);
      expect(CameraSpecification.heightPixels, 1080);
    });

    test('frame rate is 30 fps', () {
      expect(CameraSpecification.frameRate, 30);
    });

    test('video codec is H.264', () {
      expect(CameraSpecification.videoCodec, 'H.264');
    });

    test('target video bitrate is 8,000 kbps', () {
      expect(CameraSpecification.targetVideoBitrateKbps, 8000);
    });

    test('audio is AAC, mono, 128 kbps', () {
      expect(CameraSpecification.audioCodec, 'AAC');
      expect(CameraSpecification.audioChannels, 1);
      expect(CameraSpecification.audioBitrateKbps, 128);
    });

    test('the permitted zoom factors are exactly 0.5 and 0.6', () {
      // BR-02 permits these two and nothing between or beyond.
      expect(CameraSpecification.zoomFactorOptical, 0.5);
      expect(CameraSpecification.zoomFactorFallback, 0.6);
    });
  });

  group('device-tier adjustments — Volume 5.2 §2', () {
    test('resolution and frame rate are declared fixed', () {
      // §2: the pipeline "steps down bitrate (never resolution or frame
      // rate)". Named so Chapter 5.4 can grep for the rule it must honour.
      expect(CameraSpecification.resolutionIsFixed, isTrue);
    });

    test('the bitrate floor is below the target, leaving room to step', () {
      expect(
        CameraSpecification.minimumVideoBitrateKbps,
        lessThan(CameraSpecification.targetVideoBitrateKbps),
      );
    });

    test('the step divides the range into whole increments', () {
      const int range =
          CameraSpecification.targetVideoBitrateKbps -
          CameraSpecification.minimumVideoBitrateKbps;

      expect(
        range % CameraSpecification.bitrateStepKbps,
        0,
        reason: 'stepping down must land exactly on the floor, not past it',
      );
    });
  });

  group('the ladder threshold is derived, not duplicated', () {
    test('it equals the widest factor BR-02 accepts', () {
      // Written as a reference rather than a second literal so the threshold
      // and the permitted value cannot drift apart in a later edit.
      expect(
        CameraSpecification.maximumAcceptableZoomFactor,
        CameraSpecification.zoomFactorFallback,
      );
    });
  });
}
