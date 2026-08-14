import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/data/camera_capability_probe_impl.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/wide_angle_ladder.dart';

/// The probe, driven through injected readers rather than a device.
///
/// The assertion this file exists for is the tri-state one: an Android device
/// must report `null` for Tier 1, not `false`. Everything else follows from
/// that distinction being preserved.
void main() {
  CameraDescription camera({
    CameraLensDirection direction = CameraLensDirection.back,
    CameraLensType lens = CameraLensType.unknown,
    String name = 'cam',
  }) => CameraDescription(
    name: name,
    lensDirection: direction,
    sensorOrientation: 90,
    lensType: lens,
  );

  CameraCapabilityProbeImpl build({
    required List<CameraDescription> cameras,
    double? minimumZoom,
    Exception? listThrows,
    Exception? zoomThrows,
    List<CameraDescription>? zoomReads,
  }) => CameraCapabilityProbeImpl(
    cameraLister: () async {
      if (listThrows != null) {
        throw listThrows;
      }
      return cameras;
    },
    // A recording fake rather than a mock's verify(): pass a list and read
    // what landed in it. Volume 6 Ch. 6.4 §4 designs the ports for exactly
    // this substitution, and ADR-029 declined a mock framework on the
    // grounds that a fake states the collaboration in ordinary Dart.
    minimumZoomReader: (CameraDescription camera) async {
      zoomReads?.add(camera);
      if (zoomThrows != null) {
        throw zoomThrows;
      }
      return minimumZoom ?? 1.0;
    },
  );

  group('BR-01 — rear camera only', () {
    test('a device with no cameras reports no rear camera', () async {
      final CameraCapability result = await build(
        cameras: <CameraDescription>[],
      ).probe();

      expect(result, CameraCapability.noRearCamera);
    });

    test('a front-only device reports no rear camera', () async {
      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(direction: CameraLensDirection.front),
        ],
      ).probe();

      expect(result.hasRearCamera, isFalse);
    });

    test('front cameras are excluded from the ultra-wide search', () async {
      // A front ultra-wide is not a rear ultra-wide. Counting it would report
      // Tier 1 on a device that cannot satisfy BR-01 with that lens.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(
            direction: CameraLensDirection.front,
            lens: CameraLensType.ultraWide,
          ),
          camera(lens: CameraLensType.wide),
        ],
        minimumZoom: 1,
      ).probe();

      expect(result.hasDedicatedUltraWide, isFalse);
    });

    test('absent hardware returns rather than throwing', () async {
      // The ladder has a rung for this, so it is an answer and not an error.
      await expectLater(
        build(cameras: <CameraDescription>[]).probe(),
        completes,
      );
    });
  });

  group('Tier 1 is a tri-state', () {
    test('an ultra-wide rear lens reports true', () async {
      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(lens: CameraLensType.wide),
          camera(lens: CameraLensType.ultraWide, name: 'uw'),
        ],
      ).probe();

      expect(result.hasDedicatedUltraWide, isTrue);
      expect(result.ultraWideIsIndeterminate, isFalse);
    });

    test('known lens types with no ultra-wide reports false — iOS', () async {
      // camera_avfoundation populates lensType, so an absent ultra-wide here
      // is a real answer rather than an unasked question.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(lens: CameraLensType.wide),
          camera(lens: CameraLensType.telephoto, name: 'tele'),
        ],
      ).probe();

      expect(result.hasDedicatedUltraWide, isFalse);
      expect(result.ultraWideIsIndeterminate, isFalse);
    });

    test('all-unknown lens types reports NULL — Android', () async {
      // camera_android_camerax 0.7.4+5 never sets lensType, so every Android
      // device lands here whatever its hardware. Reporting false would claim
      // a phone has no ultra-wide lens when it plainly does.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[camera(), camera(name: 'cam2')],
      ).probe();

      expect(result.hasDedicatedUltraWide, isNull);
      expect(result.ultraWideIsIndeterminate, isTrue);
    });

    test('one known lens among unknowns is enough to answer', () async {
      // If the platform types any lens, it is answering the question, and
      // the absence of an ultra-wide is then genuine.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(),
          camera(lens: CameraLensType.wide, name: 'cam2'),
        ],
      ).probe();

      expect(result.hasDedicatedUltraWide, isFalse);
    });
  });

  group('Tier 2 — the zoom reading', () {
    test('the reported minimum is carried through unchanged', () async {
      // Snapping to BR-02 is the ladder's job, not the probe's. The probe
      // reports what the device said.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[camera()],
        minimumZoom: 0.53,
      ).probe();

      expect(result.minimumZoomFactor, 0.53);
    });

    group('float32 widening from the platform channel', () {
      // CameraX's ZoomState.minZoomRatio is a Java float. Widening it to a
      // Dart double is exact but not value-preserving as a reader expects:
      // 0.6f arrives as 0.6000000238418579, larger than 0.6 by 2.38e-8.
      //
      // The whole suite used clean decimal literals — 0.5, 0.6, 0.55 — so
      // nothing here could produce that value, and the gap was invisible to
      // 299 passing tests until a physical CPH2707 hit it and was refused.
      const double observedPointSix = 0.6000000238418579;

      test('the exact value observed on real hardware is normalised', () async {
        final CameraCapability result = await build(
          cameras: <CameraDescription>[camera()],
          minimumZoom: observedPointSix,
        ).probe();

        expect(result.minimumZoomFactor, 0.6);
        expect(
          result.minimumZoomFactor! <= 0.6,
          isTrue,
          reason: 'the raw value fails this comparison; the normalised one '
              'must not',
        );
      });

      test('a device reporting 0.6f resolves as HYBRID, not unsupported', () {
        // The end-to-end assertion, and the one that should have existed
        // before a real device found the gap. Driven through the ladder
        // exactly as the Checklist will.
        const CameraCapability raw = CameraCapability(
          hasRearCamera: true,
          hasDedicatedUltraWide: null,
          minimumZoomFactor: observedPointSix,
        );
        expect(
          WideAngleLadder.resolve(raw),
          isA<WideAngleEligibilityIneligible>(),
          reason: 'un-normalised, the raw value is still refused — which is '
              'why the fix belongs at the boundary that produces it',
        );

        const CameraCapability normalised = CameraCapability(
          hasRearCamera: true,
          hasDedicatedUltraWide: null,
          minimumZoomFactor: 0.6,
        );
        final WideAngleEligibility verdict = WideAngleLadder.resolve(
          normalised,
        );

        expect(verdict, isA<WideAngleEligibilityHybrid>());
        expect(verdict.zoomFactorOrNull, 0.6);
      });

      test('0.5f widening is absorbed too', () async {
        // 0.5 is exactly representable in binary, so it survives widening
        // unchanged — asserted so the fix is not mistaken for something that
        // only matters at 0.6.
        final CameraCapability result = await build(
          cameras: <CameraDescription>[camera()],
          minimumZoom: 0.5,
        ).probe();

        expect(result.minimumZoomFactor, 0.5);
      });

      test('a genuinely-too-narrow device is still refused', () {
        // The mutation this guards: normalisation must not become a rounding
        // that admits devices BR-02 excludes. 0.61 is not 0.6.
        const CameraCapability tooNarrow = CameraCapability(
          hasRearCamera: true,
          hasDedicatedUltraWide: null,
          minimumZoomFactor: 0.61,
        );

        expect(
          WideAngleLadder.resolve(tooNarrow),
          isA<WideAngleEligibilityIneligible>(),
        );
      });

      test('normalisation preserves values that differ meaningfully', () async {
        // Six decimal places is far below any distinction the ladder draws,
        // so a real measurement is carried through unchanged.
        final CameraCapability result = await build(
          cameras: <CameraDescription>[camera()],
          minimumZoom: 0.532,
        ).probe();

        expect(result.minimumZoomFactor, 0.532);
      });
    });

    test('an unreadable zoom is null, not a thrown failure', () async {
      // The lens is deliberately NOT ultraWide. A true Tier 1 now skips the
      // zoom read entirely, so an ultra-wide fixture would leave the catch in
      // `_minimumZoomOrNull` unreached and this test green for no reason.
      //
      // What it asserts: one unanswerable probe degrades to "Tier 2 did not
      // report support", which the ladder reads correctly, instead of failing
      // the whole capability read.
      final CameraCapability result = await build(
        cameras: <CameraDescription>[camera(lens: CameraLensType.wide)],
        zoomThrows: CameraException('zoomStateNotSet', 'no ZoomState'),
      ).probe();

      expect(result.minimumZoomFactor, isNull);
      expect(result.hasDedicatedUltraWide, isFalse);
    });
  });

  group('Tier 2 is only probed when Tier 1 leaves the question open', () {
    // Reading the zoom range costs a camera open and the permission that
    // comes with it. On iPhone 11 and later, Tier 1 answers from
    // `availableCameras()` alone, which needs no authorisation — so taking
    // the reading anyway would buy a shutter delay for a value the ladder
    // discards at its first branch.

    test('an affirmative Tier 1 skips the reader entirely', () async {
      final List<CameraDescription> zoomReads = <CameraDescription>[];

      final CameraCapability result = await build(
        cameras: <CameraDescription>[
          camera(lens: CameraLensType.wide),
          camera(lens: CameraLensType.ultraWide, name: 'uw'),
        ],
        zoomReads: zoomReads,
      ).probe();

      expect(zoomReads, isEmpty, reason: 'no camera should have been opened');
      expect(result.hasDedicatedUltraWide, isTrue);
      expect(
        result.minimumZoomFactor,
        isNull,
        reason: 'not read is reported as not known, which is what it is',
      );
    });

    test('a false or indeterminate Tier 1 still takes the reading', () async {
      // The other direction, so the assertion above cannot be satisfied by a
      // reader that is simply never called.
      final Map<String, CameraLensType> cases = <String, CameraLensType>{
        'false — iOS without an ultra-wide': CameraLensType.wide,
        'indeterminate — every Android device': CameraLensType.unknown,
      };

      for (final MapEntry<String, CameraLensType> entry in cases.entries) {
        final List<CameraDescription> zoomReads = <CameraDescription>[];

        final CameraCapability result = await build(
          cameras: <CameraDescription>[camera(lens: entry.value)],
          minimumZoom: 0.5,
          zoomReads: zoomReads,
        ).probe();

        expect(zoomReads, hasLength(1), reason: entry.key);
        expect(result.minimumZoomFactor, 0.5, reason: entry.key);
      }
    });
  });

  group('the conversion boundary', () {
    test('a failure to list cameras becomes a DeviceException', () async {
      // error-handling.md §26: no CameraException leaves data/.
      await expectLater(
        build(
          cameras: <CameraDescription>[],
          listThrows: CameraException('CameraAccessDenied', 'denied'),
        ).probe(),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.errorCode,
            'errorCode',
            ErrorCode.deviceCameraUnavailable,
          ),
        ),
      );
    });

    test('the raw plugin exception never escapes', () async {
      Object? caught;
      try {
        await build(
          cameras: <CameraDescription>[],
          listThrows: CameraException('whatever', 'x'),
        ).probe();
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isNot(isA<CameraException>()));
    });

    test('the message names what was attempted, not the internals', () async {
      try {
        await build(
          cameras: <CameraDescription>[],
          listThrows: CameraException('CameraAccessDenied', 'secret detail'),
        ).probe();
        fail('expected a DeviceException');
      } on DeviceException catch (error) {
        expect(error.message, contains('list the available cameras'));
        expect(error.message, isNot(contains('secret detail')));
      }
    });
  });
}
