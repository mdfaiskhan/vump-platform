import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mobile/features/recording/domain/wide_angle_ladder.dart';

/// Volume 5.1 §2's capability ladder, exhaustively.
///
/// The ladder is a pure function, so every rung and every boundary is a table
/// entry rather than a device. That matters more here than usual: the
/// alternative is verifying a three-way branch by hand on hardware, and Tier
/// 3 hard-blocks a Collector from working at all if it fires wrongly.
void main() {
  CameraCapability capability({
    bool hasRearCamera = true,
    bool? ultraWide,
    double? minimumZoom,
  }) => CameraCapability(
    hasRearCamera: hasRearCamera,
    hasDedicatedUltraWide: ultraWide,
    minimumZoomFactor: minimumZoom,
  );

  group('BR-01 is checked before the ladder', () {
    test('no rear camera is ineligible, and says so specifically', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        CameraCapability.noRearCamera,
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
      expect(
        (result as WideAngleEligibilityIneligible).reason,
        WideAngleIneligibleReason.noRearCamera,
        reason:
            'telling someone their phone lacks wide-angle when it lacks a '
            'rear camera entirely is a misleading true statement',
      );
    });

    test('no rear camera outranks a usable zoom reading', () {
      // A front-camera-only device could still report a minimum zoom. BR-01
      // is not negotiable by a Tier 2 answer.
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(hasRearCamera: false, ultraWide: true, minimumZoom: 0.5),
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
    });
  });

  group('Tier 1 — a dedicated ultra-wide lens', () {
    test('is optical at 0.5x', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: true),
      );

      expect(result, isA<WideAngleEligibilityOptical>());
      expect(result.tier, WideAngleTier.opticalDedicated);
      expect(result.zoomFactorOrNull, CameraSpecification.zoomFactorOptical);
    });

    test('wins even when the sensor also zooms out', () {
      // Order matters: the chapter tries the tiers in sequence, and a device
      // satisfying both must be reported as the better one.
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: true, minimumZoom: 0.5),
      );

      expect(result, isA<WideAngleEligibilityOptical>());
    });

    test('does not need a zoom reading at all', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: true),
      );

      expect(result.isEligible, isTrue);
    });
  });

  group('Tier 2 — the primary sensor zooms out', () {
    test('0.5x is hybrid at 0.5x', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: false, minimumZoom: 0.5),
      );

      expect(result, isA<WideAngleEligibilityHybrid>());
      expect(result.tier, WideAngleTier.primarySensorZoom);
      expect(result.zoomFactorOrNull, 0.5);
    });

    test('0.6x — the widest BR-02 accepts — is still eligible', () {
      // The boundary. One increment either side decides whether a Collector
      // can work, so it is asserted rather than assumed inclusive.
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: false, minimumZoom: 0.6),
      );

      expect(result, isA<WideAngleEligibilityHybrid>());
      expect(result.zoomFactorOrNull, CameraSpecification.zoomFactorFallback);
    });

    test('just past 0.6x is not', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: false, minimumZoom: 0.61),
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
    });

    test('1.0x — a sensor that cannot zoom out — is not', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: false, minimumZoom: 1),
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
      expect(
        (result as WideAngleEligibilityIneligible).reason,
        WideAngleIneligibleReason.noWideAngleCapability,
      );
    });
  });

  group('the reported factor is snapped into BR-02', () {
    // BR-02 permits "exactly 0.5x or 0.6x" and nothing else, but hardware
    // reports what it reports. Recording at the raw value would violate the
    // rule on its face.
    test('the exact midpoint resolves to 0.5, deterministically', () {
      // 0.55 is equidistant. Comparing the raw distances lets floating-point
      // representation error pick the answer — `0.55 - 0.5` is fractionally
      // larger than `0.6 - 0.55` — so the tie is resolved by rule instead.
      expect(
        WideAngleLadder.resolve(
          capability(ultraWide: false, minimumZoom: 0.55),
        ).zoomFactorOrNull,
        0.5,
      );
    });

    test('the midpoint gives the same answer every time', () {
      // The property the tolerance exists for: two devices reporting the same
      // figure must be given the same factor, permanently.
      final Set<double?> factors = <double?>{
        for (int i = 0; i < 20; i++)
          WideAngleLadder.resolve(
            capability(ultraWide: false, minimumZoom: 0.55),
          ).zoomFactorOrNull,
      };

      expect(factors, hasLength(1));
    });

    test('0.58 snaps to 0.6, not down to 0.5', () {
      expect(
        WideAngleLadder.resolve(
          capability(ultraWide: false, minimumZoom: 0.58),
        ).zoomFactorOrNull,
        0.6,
      );
    });

    test('a wider-than-0.5 device is clamped to 0.5, not given its reach', () {
      // Comparability across the fleet is BR-02's stated purpose, and one
      // unusually wide device defeats it.
      expect(
        WideAngleLadder.resolve(
          capability(ultraWide: false, minimumZoom: 0.25),
        ).zoomFactorOrNull,
        CameraSpecification.zoomFactorOptical,
      );
    });

    test('every eligible outcome reports a factor BR-02 permits', () {
      const List<double> reported = <double>[
        0.1,
        0.25,
        0.5,
        0.51,
        0.55,
        0.57,
        0.6,
      ];

      for (final double minimum in reported) {
        final double? factor = WideAngleLadder.resolve(
          capability(ultraWide: false, minimumZoom: minimum),
        ).zoomFactorOrNull;

        expect(
          factor,
          anyOf(
            CameraSpecification.zoomFactorOptical,
            CameraSpecification.zoomFactorFallback,
          ),
          reason: 'reported $minimum must not escape BR-02',
        );
      }
    });
  });

  group('Tier 3 fires only on a positive Tier 2 failure', () {
    // The decision recorded in A-057. "We could not look" is not evidence of
    // absence, and a wrong hard block stops a Collector working entirely.

    test('an indeterminate Tier 1 with a good zoom is hybrid, not blocked', () {
      // Every Android device today: lensType is unknown, so Tier 1 is null.
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(minimumZoom: 0.5),
      );

      expect(result, isA<WideAngleEligibilityHybrid>());
    });

    test('null Tier 1 is not treated as false Tier 1', () {
      // The mutation this guards: collapsing `hasDedicatedUltraWide ?? false`
      // into a plain false changes nothing here, but collapsing null into
      // *true* would wrongly report optical. Both misreadings are caught by
      // pinning the tier rather than only the eligibility.
      expect(
        WideAngleLadder.resolve(capability(minimumZoom: 0.5)).tier,
        WideAngleTier.primarySensorZoom,
        reason: 'an unanswerable Tier 1 must never be reported as optical',
      );
    });

    test('an unreadable zoom with an indeterminate Tier 1 blocks', () {
      // Nothing is known about this device beyond having a rear camera. The
      // ladder has no rung left, so Tier 3 is correct — and this is the one
      // case where the Android gap can produce a wrong block, which A-057
      // records as the accepted cost until the platform channel lands.
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(),
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
      expect(
        (result as WideAngleEligibilityIneligible).reason,
        WideAngleIneligibleReason.noWideAngleCapability,
      );
    });

    test('a confirmed-absent lens with an unreadable zoom blocks', () {
      final WideAngleEligibility result = WideAngleLadder.resolve(
        capability(ultraWide: false),
      );

      expect(result, isA<WideAngleEligibilityIneligible>());
    });

    test('a blocked outcome carries no zoom factor', () {
      expect(
        WideAngleLadder.resolve(capability(ultraWide: false)).zoomFactorOrNull,
        isNull,
        reason: 'there is no factor to record when nothing may be recorded',
      );
    });
  });
}
