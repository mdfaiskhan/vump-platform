import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/capture_orientation_wire_name.dart';
import 'package:mobile/features/recording/data/thermal_capture_conditions_reader.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';
import 'package:mobile/features/recording/domain/repositories/thermal_state_reader.dart';

class _FakeThermal implements ThermalStateReader {
  _FakeThermal(this.value);

  final int? value;
  int calls = 0;

  @override
  Future<int?> currentThermalState() async {
    calls += 1;
    return value;
  }
}

void main() {
  group('CaptureOrientationWireName — migration 0017', () {
    test('every orientation has a hyphenated lowercase spelling', () {
      expect(
        CaptureOrientationWireName.of(DeviceOrientation.portraitUp),
        'portrait-up',
      );
      expect(
        CaptureOrientationWireName.of(DeviceOrientation.portraitDown),
        'portrait-down',
      );
      expect(
        CaptureOrientationWireName.of(DeviceOrientation.landscapeLeft),
        'landscape-left',
      );
      expect(
        CaptureOrientationWireName.of(DeviceOrientation.landscapeRight),
        'landscape-right',
      );
    });

    test('the spelling is this project s, not the enum s name', () {
      // `DeviceOrientation.landscapeLeft.name` is `landscapeLeft`. Storing that
      // would put a Dart identifier convention in a database column and would
      // change silently if the plugin ever renamed a value.
      for (final DeviceOrientation orientation in DeviceOrientation.values) {
        expect(
          CaptureOrientationWireName.of(orientation),
          isNot(orientation.name),
        );
        expect(CaptureOrientationWireName.of(orientation), contains('-'));
      }
    });

    test(
      'ADR-054 s device-verified constant is the landscapeLeft spelling',
      () {
        // The constant measured on a CPH2707: landscapeLeft produced a 0-degree
        // rotation tag, landscapeRight produced 180 degrees — upside-down.
        expect(CaptureOrientationWireName.landscapeLeft, 'landscape-left');
        expect(
          CaptureOrientationWireName.of(DeviceOrientation.landscapeLeft),
          CaptureOrientationWireName.landscapeLeft,
        );
      },
    );
  });

  group('ThermalCaptureConditionsReader — migration 0017', () {
    test('reports the thermal state and leaves the other three null', () {
      // The name says thermal because thermal is all it reads. GPS is blocked
      // on A-062's spec conflict; battery and network have readers that exist
      // but are wired to the Checklist rather than to metadata.
      final _FakeThermal thermal = _FakeThermal(2);

      return ThermalCaptureConditionsReader(thermalReader: thermal).read().then(
        (MetadataCaptureConditions conditions) {
          expect(conditions.thermalState, 2);
          expect(conditions.gps, isNull);
          expect(conditions.batteryPercent, isNull);
          expect(conditions.networkType, isNull);
          expect(thermal.calls, 1);
        },
      );
    });

    test('a null reading is carried through, not defaulted', () async {
      final MetadataCaptureConditions conditions =
          await ThermalCaptureConditionsReader(
            thermalReader: _FakeThermal(null),
          ).read();

      expect(conditions.thermalState, isNull);
    });

    test('zero is carried through as a reading', () async {
      final MetadataCaptureConditions conditions =
          await ThermalCaptureConditionsReader(
            thermalReader: _FakeThermal(0),
          ).read();

      expect(conditions.thermalState, 0);
      expect(conditions.isEmpty, isFalse);
    });
  });

  group('isComplete and isEmpty disagree about thermal, on purpose', () {
    test('isComplete ignores it, because Chapter 4.5 does not list it', () {
      // Chapter 4.5 names three conditions. Thermal arrived with 0017, after
      // the chapter, so folding it into `isComplete` would silently change
      // what an existing predicate means.
      const MetadataCaptureConditions thermalOnly = MetadataCaptureConditions(
        thermalState: 4,
      );

      expect(thermalOnly.isComplete, isFalse);

      const MetadataCaptureConditions chapterComplete =
          MetadataCaptureConditions(
            gps: null,
            batteryPercent: 80,
            networkType: 'wifi',
          );

      // Still false: gps is absent. The point is that adding thermal did not
      // move this predicate in either direction.
      expect(chapterComplete.isComplete, isFalse);
    });

    test('isEmpty counts it, because it is a question about this object', () {
      const MetadataCaptureConditions thermalOnly = MetadataCaptureConditions(
        thermalState: 4,
      );

      expect(thermalOnly.isEmpty, isFalse);
      expect(MetadataCaptureConditions.unavailable.isEmpty, isTrue);
    });
  });
}
