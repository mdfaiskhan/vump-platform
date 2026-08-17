import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/presentation/recording_error_copy.dart';

/// What a Collector reads when recording fails.
///
/// The assertion that matters is **totality**: Volume 2 Chapter 2.9 §2 makes a
/// generic message a defect rather than a fallback, so every `ErrorCode` — not
/// just the handful this feature produces today — must yield a specific cause
/// and a specific action.
void main() {
  group('totality — no code can produce an empty or generic message', () {
    test('every ErrorCode in the taxonomy yields a message', () {
      for (final ErrorCode code in ErrorCode.values) {
        expect(
          RecordingErrorCopy.forFailure(Failure(code: code)),
          isNotEmpty,
          reason: code.code,
        );
      }
    });

    test('no message is a bare error word', () {
      for (final ErrorCode code in ErrorCode.values) {
        final String message = RecordingErrorCopy.forFailure(
          Failure(code: code),
        );

        expect(
          message.trim(),
          isNot(anyOf('Error', 'Failed', 'Something went wrong')),
          reason: code.code,
        );
        expect(
          message.split(' ').length,
          greaterThan(5),
          reason: '${code.code} must state a cause and an action',
        );
      }
    });

    test('the message never leaks a code or a plugin string', () {
      // error-handling.md: `Failure.message` is developer-facing and may name
      // internal details; what presentation renders must not.
      for (final ErrorCode code in ErrorCode.values) {
        final String message = RecordingErrorCopy.forFailure(
          Failure(code: code),
        );

        expect(message, isNot(contains('_')));
        expect(message, isNot(contains(code.code)));
      }
    });
  });

  group('the codes this feature actually produces are distinguished', () {
    test('camera and microphone refusals differ', () {
      // Mission 3.8 split these so C-08 could name the right Settings toggle.
      final String camera = RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.devicePermissionCameraDenied),
      );
      final String microphone = RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.devicePermissionMicrophoneDenied),
      );

      expect(camera, isNot(microphone));
      expect(camera, contains('Camera'));
      expect(microphone, contains('Microphone'));
    });

    test('an absent rear camera is not framed as a permission problem', () {
      final String message = RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.deviceRearCameraAbsent),
      );

      expect(message, isNot(contains('Settings')));
      expect(message, contains('different device'));
    });

    test('a busy camera is distinguished from a refused one', () {
      // Different cause, different action: close the other app rather than
      // open Settings.
      final String busy = RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.deviceCameraUnavailable),
      );

      expect(busy, contains('other app'));
      expect(busy, isNot(contains('Settings')));
    });

    test('a wide-angle block tells the Collector to change device', () {
      // Tier 3. Nothing the person can do on this handset, so the action must
      // not imply otherwise.
      expect(
        RecordingErrorCopy.forFailure(
          const Failure(code: ErrorCode.deviceWideAngleUnsupported),
        ),
        contains('different device'),
      );
    });

    test('a full disk is actionable, not a retry — Ch. 5.13 §1', () {
      // Terminal and device-side: "not retried automatically".
      final String message = RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.storageWriteFailed),
      );

      expect(message, contains('Free up storage'));
    });
  });

  test('the message ignores Failure.message and reads only the code', () {
    // error-handling.md §26 puts presentation in exactly this position: match
    // on `code`, never on a message string, because the message is nullable
    // and written for a log reader.
    expect(
      RecordingErrorCopy.forFailure(
        const Failure(
          code: ErrorCode.deviceCameraUnavailable,
          message: 'CameraException(cameraNotReadable, in use by com.foo)',
        ),
      ),
      RecordingErrorCopy.forFailure(
        const Failure(code: ErrorCode.deviceCameraUnavailable),
      ),
    );
  });
}
