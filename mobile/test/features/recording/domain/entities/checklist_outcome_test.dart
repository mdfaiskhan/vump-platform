import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/recording_lifecycle.dart';

/// BR-04's verdict, derived from five readings.
///
/// The assertions worth having are the ones about **what does not pass**: an
/// unmeasured row, a row at exactly the threshold, and the one row that
/// reports without gating.
void main() {
  ChecklistOutcome allPassing() => const ChecklistOutcome(
    permissionsGranted: true,
    availableBytes: RecordingLifecycle.oneChunkBytes,
    batteryPercent: ChecklistOutcome.minimumBatteryPercent,
    network: NetworkType.wifi,
    wideAngle: WideAngleEligibility.hybrid(zoomFactor: 0.6),
  );

  group('an unmeasured row never passes', () {
    test('the pending outcome passes nothing and blocks BR-04', () {
      const ChecklistOutcome outcome = ChecklistOutcome.pending;

      for (final ChecklistCheck check in ChecklistCheck.values) {
        expect(outcome.passes(check), isFalse, reason: check.name);
        expect(outcome.isMeasured(check), isFalse, reason: check.name);
      }
      expect(outcome.allPassed, isFalse);
    });

    test('pending rows are not reported as failures', () {
      // C-08 expands failing rows with a remedy. A checklist mid-run must not
      // render five red rows before it has looked at anything.
      expect(ChecklistOutcome.pending.failures, isEmpty);
    });

    test('one row still pending blocks the whole verdict', () {
      expect(allPassing().copyWith(batteryPercent: null).allPassed, isFalse);
    });
  });

  group('thresholds are inclusive, and sourced', () {
    test('battery exactly at the minimum passes', () {
      expect(
        allPassing()
            .copyWith(batteryPercent: ChecklistOutcome.minimumBatteryPercent)
            .passes(ChecklistCheck.batteryLevel),
        isTrue,
      );
    });

    test('one percent below the minimum fails', () {
      expect(
        allPassing()
            .copyWith(
              batteryPercent: ChecklistOutcome.minimumBatteryPercent - 1,
            )
            .passes(ChecklistCheck.batteryLevel),
        isFalse,
      );
    });

    test('the battery minimum is the 20% the volumes state', () {
      // Volume 1's UC-05 remedy and Volume 2 Ch. 2.7 C-08 / Ch. 2.9 §3 all
      // say "at least 20%". FR-CHK-03 names a threshold without a number;
      // this is that number, and it was not chosen here.
      expect(ChecklistOutcome.minimumBatteryPercent, 20);
    });

    test('free space exactly one chunk passes', () {
      expect(
        allPassing()
            .copyWith(availableBytes: RecordingLifecycle.oneChunkBytes)
            .passes(ChecklistCheck.freeStorage),
        isTrue,
      );
    });

    test('one byte short fails', () {
      expect(
        allPassing()
            .copyWith(availableBytes: RecordingLifecycle.oneChunkBytes - 1)
            .passes(ChecklistCheck.freeStorage),
        isFalse,
      );
    });

    test('the storage floor is the pipelines floor, not a second copy', () {
      // FR-CHK-02 and Ch. 5.4 §2 must not drift: the pipeline can never allow
      // less headroom than the Checklist demanded before it started.
      expect(
        ChecklistOutcome.minimumFreeBytes,
        RecordingLifecycle.oneChunkBytes,
      );
    });
  });

  group('the network row reports and never blocks', () {
    test('offline still passes — Ch. 2.9 §5', () {
      // "the checklist's network check only determines whether upload starts
      // immediately or is queued, never whether recording is allowed to
      // proceed."
      final ChecklistOutcome offline = allPassing().copyWith(
        network: NetworkType.none,
      );

      expect(offline.passes(ChecklistCheck.network), isTrue);
      expect(offline.allPassed, isTrue);
    });

    test('every connection kind passes', () {
      for (final NetworkType type in NetworkType.values) {
        expect(
          allPassing().copyWith(network: type).allPassed,
          isTrue,
          reason: type.name,
        );
      }
    });

    test('but an unmeasured network row still blocks', () {
      // Not gating on the value is different from not needing the reading.
      expect(allPassing().copyWith(network: null).allPassed, isFalse);
    });
  });

  group('wide angle gates, and supplies the factor', () {
    test('an ineligible verdict blocks BR-04', () {
      final ChecklistOutcome outcome = allPassing().copyWith(
        wideAngle: const WideAngleEligibility.ineligible(
          reason: WideAngleIneligibleReason.noWideAngleCapability,
        ),
      );

      expect(outcome.passes(ChecklistCheck.wideAngleCapability), isFalse);
      expect(outcome.allPassed, isFalse);
      expect(outcome.resolvedZoomFactor, isNull);
    });

    test('the resolved factor is the ladders, carried unchanged', () {
      // Ch. 5.2 §1 fixes it for the whole session; the Checklist resolves it
      // and the lifecycle does not revisit the verdict.
      expect(
        allPassing()
            .copyWith(
              wideAngle: const WideAngleEligibility.optical(zoomFactor: 0.5),
            )
            .resolvedZoomFactor,
        0.5,
      );
      expect(allPassing().resolvedZoomFactor, 0.6);
    });
  });

  group('failures name every failing row, not just the first', () {
    test('two bad rows both appear — FR-CHK-05 names the specific check', () {
      final ChecklistOutcome outcome = allPassing().copyWith(
        batteryPercent: 5,
        permissionsGranted: false,
      );

      expect(outcome.failures, <ChecklistCheck>[
        ChecklistCheck.cameraAndMicrophone,
        ChecklistCheck.batteryLevel,
      ]);
    });

    test('all passing means no failures and BR-04 is satisfied', () {
      expect(allPassing().failures, isEmpty);
      expect(allPassing().allPassed, isTrue);
    });
  });
}
