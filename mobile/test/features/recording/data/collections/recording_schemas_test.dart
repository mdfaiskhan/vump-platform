import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/features/recording/data/collections/recording_schemas.dart';

/// The schema list handed to `DatabaseConfig` at the composition root.
///
/// A schema missing from this list does not fail to compile — it fails at
/// runtime, on the device, the first time something opens that collection.
/// That is the failure this asserts against: the list is pinned by name and by
/// length, so removing an entry breaks a test rather than a recording.
void main() {
  test('carries exactly the three recording collections', () {
    expect(RecordingSchemas.all, hasLength(3));

    expect(
      RecordingSchemas.all
          .map((CollectionSchema<dynamic> s) => s.name)
          .toList(),
      containsAll(<String>['LocalSession', 'LocalChunk', 'LocalChunkMetadata']),
    );
  });

  test('holds no duplicate collection', () {
    // A duplicated schema is accepted by Isar and then shadows itself; the
    // symptom is a collection that silently reads empty.
    final List<String> names = RecordingSchemas.all
        .map((CollectionSchema<dynamic> s) => s.name)
        .toList();

    expect(names.toSet(), hasLength(names.length));
  });
}
