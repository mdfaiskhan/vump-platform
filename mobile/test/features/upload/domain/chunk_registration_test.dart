import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/upload/domain/entities/chunk_registration.dart';
import 'package:mobile/features/upload/domain/entities/upload_failure_cause.dart';

/// Volume 4 Chapter 4.6 §5's response, as a value.
void main() {
  ChunkRegistration registration({
    String chunkId = 'chk_1',
    String key = 'org/proj/task/sess/0003_chk_1.mp4',
    List<String> urls = const <String>['https://s3.example/part-1'],
  }) => ChunkRegistration(chunkId: chunkId, s3ObjectKey: key, uploadUrls: urls);

  group('hasParts', () {
    test('true when the backend issued at least one URL', () {
      expect(registration().hasParts, isTrue);
    });

    test('false for an empty list, which is malformed not empty', () {
      // A finalized chunk always has bytes, so there is always at least one
      // part. Zero URLs is a broken response, not a zero-part upload.
      expect(registration(urls: const <String>[]).hasParts, isFalse);
    });
  });

  group('value semantics', () {
    test('same fields are equal and share a hashCode', () {
      expect(registration(), registration());
      expect(registration().hashCode, registration().hashCode);
      expect(<ChunkRegistration>{registration(), registration()}, hasLength(1));
    });

    test('identical is equal', () {
      final ChunkRegistration one = registration();
      expect(one, one);
    });

    test('a different chunk id is a different value', () {
      expect(registration(), isNot(registration(chunkId: 'chk_2')));
    });

    test('a different key is a different value', () {
      expect(registration(), isNot(registration(key: 'other/key.mp4')));
    });

    test('a different URL at the same position is a different value', () {
      expect(
        registration(),
        isNot(registration(urls: const <String>['https://s3.example/other'])),
      );
    });

    test('a different part count is a different value', () {
      expect(
        registration(),
        isNot(
          registration(
            urls: const <String>[
              'https://s3.example/part-1',
              'https://s3.example/part-2',
            ],
          ),
        ),
      );
    });

    test('URL order matters — parts are positional', () {
      // Part N goes to URL N. Two registrations with the same URLs in a
      // different order would upload the same bytes to different part numbers.
      const List<String> forward = <String>['a', 'b'];
      const List<String> reversed = <String>['b', 'a'];

      expect(registration(urls: forward), isNot(registration(urls: reversed)));
    });

    test('a non-registration is not equal', () {
      expect(registration() == Object(), isFalse);
    });
  });

  test('toString reports the part count and never the URLs', () {
    // Printing the list would put every presigned signature into whatever log
    // or test failure rendered this object.
    final String text = registration(
      urls: const <String>[
        'https://s3.example/p1?X-Amz-Signature=deadbeef',
        'https://s3.example/p2?X-Amz-Signature=cafe',
      ],
    ).toString();

    expect(text, contains('chk_1'));
    expect(text, contains('2 parts'));
    expect(text, isNot(contains('X-Amz-Signature')));
    expect(text, isNot(contains('deadbeef')));
  });

  group('UploadFailureCause carries Chapter 5.13 §1s classification', () {
    test('only transport and storage failures are transient', () {
      final Set<UploadFailureCause> transient = UploadFailureCause.values
          .where((UploadFailureCause c) => c.isTransient)
          .toSet();

      expect(transient, <UploadFailureCause>{
        UploadFailureCause.transportFailure,
        UploadFailureCause.storageFailure,
      });
    });

    test('every terminal cause is one the chapter names', () {
      // Chapter 5.13 §1's two terminal rows: device-side and server-side.
      // Nothing here is a new failure semantic.
      final Set<UploadFailureCause> terminal = UploadFailureCause.values
          .where((UploadFailureCause c) => !c.isTransient)
          .toSet();

      expect(terminal, <UploadFailureCause>{
        UploadFailureCause.identityIncomplete,
        UploadFailureCause.metadataMissing,
        UploadFailureCause.fileUnavailable,
        UploadFailureCause.sessionUnregisterable,
        UploadFailureCause.rejectedByBackend,
        UploadFailureCause.malformedResponse,
      });
    });
  });
}
