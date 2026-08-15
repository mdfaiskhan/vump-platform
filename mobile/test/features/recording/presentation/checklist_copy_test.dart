import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';
import 'package:mobile/features/recording/presentation/checklist_copy.dart';

/// The words on C-07 and C-08, and the rules Volume 2 puts on them.
///
/// These are pure functions, so what is testable is the property Chapter 2.9
/// §2 actually cares about: **that no row can reach the screen without a
/// specific cause and a specific fix.** A generic message there is a defect,
/// not a fallback, so totality is the assertion — not the exact wording.
void main() {
  const ChecklistOutcome measured = ChecklistOutcome(
    permissionsGranted: false,
    permissionFailure: ErrorCode.devicePermissionCameraDenied,
    availableBytes: 1000,
    batteryPercent: 4,
    network: NetworkType.none,
    wideAngle: WideAngleEligibility.ineligible(
      reason: WideAngleIneligibleReason.noWideAngleCapability,
    ),
  );

  group('every row has a label, a value and a remedy — Ch. 2.9 §4.3', () {
    test('no check produces an empty label', () {
      for (final ChecklistCheck check in ChecklistCheck.values) {
        expect(ChecklistCopy.label(check), isNotEmpty, reason: check.name);
      }
    });

    test('no check produces an empty remedy', () {
      // "never an error with no action attached" — Ch. 2.9 §4.3. The network
      // row is included even though it cannot fail, so the function stays
      // total and no future change can reach the screen without a fix.
      for (final ChecklistCheck check in ChecklistCheck.values) {
        expect(
          ChecklistCopy.remedy(check, measured),
          isNotEmpty,
          reason: check.name,
        );
      }
    });

    test('no remedy is a bare error word — Ch. 2.9 §2', () {
      // "A generic 'Something went wrong' is treated as a defect, not an
      // acceptable fallback."
      for (final ChecklistCheck check in ChecklistCheck.values) {
        final String remedy = ChecklistCopy.remedy(check, measured);
        expect(remedy.trim(), isNot(anyOf('Error', 'Failed', 'Try again')));
        expect(
          remedy.split(' ').length,
          greaterThan(4),
          reason: '${check.name} must state a specific action',
        );
      }
    });
  });

  group('values are shown, never left to an icon — Ch. 2.10', () {
    test('an unmeasured row says it is still checking', () {
      // Not an empty string, which would read as zero, and not a failure.
      for (final ChecklistCheck check in ChecklistCheck.values) {
        expect(
          ChecklistCopy.value(check, ChecklistOutcome.pending),
          'Checking…',
          reason: check.name,
        );
      }
    });

    test('battery renders as a percentage — C-07s worked example', () {
      expect(
        ChecklistCopy.value(
          ChecklistCheck.batteryLevel,
          const ChecklistOutcome(batteryPercent: 82),
        ),
        'Battery: 82%'.split(': ').last,
      );
    });

    test('permission renders both outcomes distinctly', () {
      expect(
        ChecklistCopy.value(
          ChecklistCheck.cameraAndMicrophone,
          const ChecklistOutcome(permissionsGranted: true),
        ),
        'Allowed',
      );
      expect(
        ChecklistCopy.value(
          ChecklistCheck.cameraAndMicrophone,
          const ChecklistOutcome(permissionsGranted: false),
        ),
        'Not allowed',
      );
    });

    test('storage renders decimal GB, matching the phones own display', () {
      // Decimal rather than GiB: a checklist that disagreed with Settings by
      // 7% would look wrong to the person reading both.
      expect(
        ChecklistCopy.value(
          ChecklistCheck.freeStorage,
          const ChecklistOutcome(availableBytes: 2500000000),
        ),
        '2.5 GB',
      );
    });

    test('each connection kind renders a distinct, readable value', () {
      // The row's VALUE, which is separate from uploadExpectation's sentence.
      // "Wi-Fi" and "Mobile data" are what a Collector reads, not the wire
      // spellings Chapter 4.5 stores.
      expect(
        ChecklistCopy.value(
          ChecklistCheck.network,
          const ChecklistOutcome(network: NetworkType.wifi),
        ),
        'Wi-Fi',
      );
      expect(
        ChecklistCopy.value(
          ChecklistCheck.network,
          const ChecklistOutcome(network: NetworkType.cellular),
        ),
        'Mobile data',
      );
      expect(
        ChecklistCopy.value(
          ChecklistCheck.network,
          const ChecklistOutcome(network: NetworkType.none),
        ),
        'Offline',
      );
    });

    test('an optical device is labelled as an ultra-wide lens', () {
      // Tier 1 — the iOS path. Distinct from Tier 2's plain "wide", because
      // the two reach the same field of view by different means and the
      // metadata records which.
      expect(
        ChecklistCopy.value(
          ChecklistCheck.wideAngleCapability,
          const ChecklistOutcome(
            wideAngle: WideAngleEligibility.optical(zoomFactor: 0.5),
          ),
        ),
        contains('ultra-wide'),
      );
    });

    test('the wide-angle row shows the resolved factor, not just a tier', () {
      expect(
        ChecklistCopy.value(
          ChecklistCheck.wideAngleCapability,
          const ChecklistOutcome(
            wideAngle: WideAngleEligibility.hybrid(zoomFactor: 0.6),
          ),
        ),
        contains('0.6'),
      );
      expect(
        ChecklistCopy.value(
          ChecklistCheck.wideAngleCapability,
          const ChecklistOutcome(
            wideAngle: WideAngleEligibility.ineligible(
              reason: WideAngleIneligibleReason.noWideAngleCapability,
            ),
          ),
        ),
        'Not supported',
      );
    });
  });

  group('the permission remedy names WHICH grant — FR-CHK-05', () {
    test('a camera refusal names the camera', () {
      final String remedy = ChecklistCopy.remedy(
        ChecklistCheck.cameraAndMicrophone,
        const ChecklistOutcome(
          permissionsGranted: false,
          permissionFailure: ErrorCode.devicePermissionCameraDenied,
        ),
      );

      expect(remedy, contains('Camera'));
      expect(remedy, isNot(contains('Microphone')));
    });

    test('a microphone refusal names the microphone', () {
      // The distinction Mission 3.8 split the error codes for. Collapsing
      // these would send someone to the wrong Settings toggle.
      final String remedy = ChecklistCopy.remedy(
        ChecklistCheck.cameraAndMicrophone,
        const ChecklistOutcome(
          permissionsGranted: false,
          permissionFailure: ErrorCode.devicePermissionMicrophoneDenied,
        ),
      );

      expect(remedy, contains('Microphone'));
      expect(remedy, isNot(contains('Camera access')));
    });

    test('an absent rear camera is not reported as a refusal', () {
      // BR-01. Nothing to grant, so "enable it in Settings" would be wrong.
      final String remedy = ChecklistCopy.remedy(
        ChecklistCheck.cameraAndMicrophone,
        const ChecklistOutcome(
          permissionsGranted: false,
          permissionFailure: ErrorCode.deviceRearCameraAbsent,
        ),
      );

      expect(remedy, contains('no rear camera'));
      expect(remedy, isNot(contains('Settings')));
    });

    test('an unknown device code still names a cause and an action', () {
      final String remedy = ChecklistCopy.remedy(
        ChecklistCheck.cameraAndMicrophone,
        const ChecklistOutcome(
          permissionsGranted: false,
          permissionFailure: ErrorCode.storageCorrupted,
        ),
      );

      expect(remedy, isNotEmpty);
      expect(remedy, contains('again'));
    });
  });

  group('the storage and battery remedies quote the real thresholds', () {
    test('the battery remedy states the configured minimum', () {
      expect(
        ChecklistCopy.remedy(ChecklistCheck.batteryLevel, measured),
        contains('${ChecklistOutcome.minimumBatteryPercent}%'),
      );
    });

    test('the storage remedy is derived from oneChunkBytes, not a literal', () {
      // If the constant moves — A-064 §4b flags that it might — this copy
      // must move with it rather than quoting a stale number at a Collector.
      final String remedy = ChecklistCopy.remedy(
        ChecklistCheck.freeStorage,
        measured,
      );
      const double gb =
          RecordingLifecycle.oneChunkBytes / (1000 * 1000 * 1000);

      expect(remedy, contains(gb.toStringAsFixed(1)));
    });
  });

  group('FR-CHK-04 tells the Collector what happens to uploads', () {
    test('each connection kind gets its own sentence', () {
      final Set<String> sentences = <String>{
        for (final NetworkType type in NetworkType.values)
          ChecklistCopy.uploadExpectation(type),
      };

      expect(sentences, hasLength(NetworkType.values.length));
      for (final String sentence in sentences) {
        expect(sentence, isNotEmpty);
      }
    });

    test('offline says uploads queue, not that recording is blocked', () {
      // Ch. 2.9 §5: the network check "never determines whether recording is
      // allowed to proceed".
      final String offline = ChecklistCopy.uploadExpectation(NetworkType.none);

      expect(offline, contains('queue'));
      expect(offline.toLowerCase(), isNot(contains('cannot record')));
    });

    test('an unmeasured network says nothing rather than guessing', () {
      expect(ChecklistCopy.uploadExpectation(null), isEmpty);
    });
  });
}
