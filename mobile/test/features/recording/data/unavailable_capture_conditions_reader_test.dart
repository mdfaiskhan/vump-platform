import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/unavailable_capture_conditions_reader.dart';
import 'package:mobile/features/recording/domain/entities/metadata_capture_conditions.dart';

/// The reader that reports nothing, on purpose.
///
/// A-062 §1 records that GPS, battery and network are schema-only fields with
/// no source, and this class is how that absence is expressed: every value is
/// null rather than zero or a plausible default. The test exists because the
/// tempting "fix" — filling one field in because a source became available —
/// would silently change what a stored chunk claims about the conditions it
/// was recorded in, and nothing else asserts that these stay absent.
void main() {
  test('reads as unavailable, with every value absent', () async {
    const UnavailableCaptureConditionsReader reader =
        UnavailableCaptureConditionsReader();

    final MetadataCaptureConditions conditions = await reader.read();

    expect(conditions, MetadataCaptureConditions.unavailable);
  });

  test('two reads return the same constant rather than fresh instances', () {
    // It is a `const` reader over a `const` value; nothing here should
    // allocate per call.
    const UnavailableCaptureConditionsReader a =
        UnavailableCaptureConditionsReader();
    const UnavailableCaptureConditionsReader b =
        UnavailableCaptureConditionsReader();

    expect(identical(a, b), isTrue);
  });
}
