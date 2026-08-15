import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/upload/metadata/metadata_capture_conditions_document.dart';
import 'package:mobile/core/upload/metadata/metadata_identity_document.dart';
import 'package:mobile/core/upload/metadata/metadata_timing_document.dart';

import '../fakes/metadata_document_builders.dart';

/// Volume 4 Chapter 4.5 §2's shape, pinned.
///
/// `toJson` is hand-written, so this is what stops it drifting. The document
/// is evidence — BR-22 makes it immutable once the backend stores it — and a
/// silently reshaped field would be wrong permanently rather than until the
/// next deploy.
void main() {
  group('Chapter 4.5 §2 — the canonical shape', () {
    test('every group and key matches the chapter, exactly', () {
      final Map<String, Object?> json = completeIdentityDocument().toJson();

      // The chapter's own structure: chunk_id, then seven groups.
      expect(json.keys, <String>[
        'chunk_id',
        'identity',
        'timing',
        'capture',
        'device_context',
        'capture_conditions',
        'integrity',
        'collector_authored',
      ]);

      expect(json['identity'], <String, Object?>{
        'session_id': 'sess_e810',
        'project_id': 'proj_4a1',
        'task_id': 'task_7c3',
        'collector_id': 'user_22b',
        'device_id': 'dev_5f0',
      });

      expect(json['timing'], <String, Object?>{
        'sequence_index': 3,
        'started_at': '2026-08-15T09:00:00.000Z',
        'ended_at': '2026-08-15T09:10:00.000Z',
        'duration_seconds': 600,
      });

      expect(json['capture'], <String, Object?>{
        'resolution': '1920x1080',
        'frame_rate': 30,
        'bitrate_kbps': 8000,
        'codec': 'h264',
        'zoom_factor': 0.6,
        'camera': 'rear-wide',
      });

      expect(json['device_context'], <String, Object?>{
        'device_model': 'Pixel 6a',
        'os_version': 'Android 15',
        'app_version': '1.0.0+1',
      });

      expect(json['integrity'], <String, Object?>{
        'file_size_bytes': 512000000,
        'checksum_sha256': 'abc123',
      });

      expect(json['collector_authored'], <String, Object?>{
        'notes': null,
        'tags': <String>[],
      });
    });

    test('capture_conditions nests gps as lat/lng, not latitude/longitude', () {
      // The three names the chapter uses that differ from the Dart fields.
      // This is the assertion a code generator would have needed telling about
      // individually anyway, which is why toJson is written by hand.
      final Map<String, Object?> json = const MetadataCaptureConditionsDocument(
        latitude: 12.5,
        longitude: -3.25,
        batteryPercent: 82,
        networkType: 'wifi',
      ).toJson();

      expect(json, <String, Object?>{
        'gps': <String, Object?>{'lat': 12.5, 'lng': -3.25},
        'battery_pct': 82,
        'network_type': 'wifi',
      });
    });

    test('a missing fix is null coordinates, never {0.0, 0.0}', () {
      // {0, 0} is a real place in the Gulf of Guinea. A plausible wrong value
      // is harder to catch than an obviously empty one — the same argument
      // MetadataCaptureConditions made when it rejected zeroes.
      const MetadataCaptureConditionsDocument absent =
          MetadataCaptureConditionsDocument();

      expect(absent.hasFix, isFalse);
      expect(absent.toJson()['gps'], <String, Object?>{
        'lat': null,
        'lng': null,
      });
    });

    test(
      'the gps key is always present, so absent and unimplemented differ',
      () {
        // Omitting the key would make "no fix taken" and "this build does not
        // collect GPS" the same wire value.
        expect(
          const MetadataCaptureConditionsDocument().toJson().containsKey('gps'),
          isTrue,
        );
      },
    );
  });

  group('timing.duration_seconds is derived', () {
    test('computed from the two timestamps', () {
      final MetadataTimingDocument timing = MetadataTimingDocument(
        startedAt: DateTime.utc(2026, 8, 15, 9),
        endedAt: DateTime.utc(2026, 8, 15, 9, 10),
      );

      expect(timing.durationSeconds, 600);
    });

    test('null when an endpoint is missing, never zero', () {
      // A zero would read as a chunk of no length — a claim, where null is an
      // absence.
      expect(
        MetadataTimingDocument(startedAt: DateTime.utc(2026)).durationSeconds,
        isNull,
      );
      expect(
        MetadataTimingDocument(endedAt: DateTime.utc(2026)).durationSeconds,
        isNull,
      );
      expect(const MetadataTimingDocument().durationSeconds, isNull);
    });

    test('timestamps serialise as UTC with an explicit Z', () {
      // toIso8601String on a local DateTime emits no offset at all, which a
      // backend would have to guess at.
      final Map<String, Object?> json = MetadataTimingDocument(
        startedAt: DateTime.utc(2026, 8, 15, 9).toLocal(),
        endedAt: DateTime.utc(2026, 8, 15, 9, 10).toLocal(),
      ).toJson();

      expect(json['started_at'], endsWith('Z'));
      expect(json['started_at'], '2026-08-15T09:00:00.000Z');
    });
  });

  group('A-068 Guard 1 — isIdentityComplete', () {
    test('true only when all five fields name something', () {
      expect(completeIdentityDocument().isIdentityComplete, isTrue);
    });

    test('false for a real recorded chunk, which is every chunk today', () {
      // Four of five carry MetadataIdentity.unsourced — the empty string.
      expect(unsourcedIdentityDocument().isIdentityComplete, isFalse);
    });

    test('blank fails, not only null', () {
      // ChunkRecordMapper writes '' rather than null, so a null-only check
      // would pass every chunk this application has ever recorded.
      expect(
        const MetadataIdentityDocument(
          sessionId: 's',
          projectId: 'p',
          taskId: 't',
          collectorId: '',
          deviceId: 'd',
        ).isComplete,
        isFalse,
      );
    });

    test('null fails too', () {
      expect(
        const MetadataIdentityDocument(
          sessionId: 's',
          projectId: 'p',
          taskId: 't',
          deviceId: 'd',
        ).isComplete,
        isFalse,
      );
    });

    test('each of the five fields is checked, none skipped', () {
      const List<MetadataIdentityDocument> eachBlank =
          <MetadataIdentityDocument>[
            MetadataIdentityDocument(
              projectId: 'p',
              taskId: 't',
              collectorId: 'c',
              deviceId: 'd',
            ),
            MetadataIdentityDocument(
              sessionId: 's',
              taskId: 't',
              collectorId: 'c',
              deviceId: 'd',
            ),
            MetadataIdentityDocument(
              sessionId: 's',
              projectId: 'p',
              collectorId: 'c',
              deviceId: 'd',
            ),
            MetadataIdentityDocument(
              sessionId: 's',
              projectId: 'p',
              taskId: 't',
              deviceId: 'd',
            ),
            MetadataIdentityDocument(
              sessionId: 's',
              projectId: 'p',
              taskId: 't',
              collectorId: 'c',
            ),
          ];

      expect(
        eachBlank.map((MetadataIdentityDocument i) => i.isComplete),
        everyElement(isFalse),
      );
    });

    test('missingFields names them, in schema order', () {
      // Ch. 2.9 §2 forbids a failure that does not name its specific cause.
      expect(unsourcedIdentityDocument().identity.missingFields, <String>[
        'project_id',
        'task_id',
        'collector_id',
        'device_id',
      ]);
    });

    test('missingFields is empty when the group is complete', () {
      expect(completeIdentityDocument().identity.missingFields, isEmpty);
    });
  });

  test('toString reports the guard verdict, not the document', () {
    expect(
      unsourcedIdentityDocument().toString(),
      'ChunkMetadataDocument(chk_1, identityComplete: false)',
    );
  });
}
