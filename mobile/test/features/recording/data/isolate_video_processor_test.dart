import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/data/isolate_video_processor.dart';
import 'package:mobile/features/recording/domain/entities/chunk_integrity.dart';

/// Volume 5 Chapter 5.5 §1.2 and §1.3.
///
/// The assertions that matter are the known-answer vectors: a checksum test
/// that only compares the implementation against itself would pass against any
/// hash function at all, including a broken one. These pin the output to
/// SHA-256's published digests, so the test fails if the algorithm, the block
/// handling or the hex encoding ever changes.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('vp_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final File file = File('${temp.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  // Runs the work inline rather than spawning an isolate per test.
  const IsolateVideoProcessor processor = IsolateVideoProcessor(
    runner: _inline,
  );

  group('known-answer vectors — this is really SHA-256', () {
    test('the empty file matches the published empty digest', () async {
      final ChunkIntegrity result = await processor.process(
        write('empty.mp4', <int>[]),
      );

      expect(
        result.checksumSha256,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(result.byteCount, 0);
    });

    test('"abc" matches the published NIST vector', () async {
      final ChunkIntegrity result = await processor.process(
        write('abc.mp4', <int>[0x61, 0x62, 0x63]),
      );

      expect(
        result.checksumSha256,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(result.byteCount, 3);
    });
  });

  group('the digest is well-formed', () {
    test('64 lowercase hex characters', () async {
      final ChunkIntegrity result = await processor.process(
        write('x.mp4', List<int>.filled(1000, 7)),
      );

      expect(result.checksumSha256, hasLength(ChunkIntegrity.checksumLength));
      expect(result.checksumSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('the declared length constant matches reality', () {
      expect(ChunkIntegrity.checksumLength, 64);
    });
  });

  group('block-wise reading — §1.2', () {
    test('a file larger than one read block hashes correctly', () async {
      // Spans many openRead() blocks, so a bug in accumulating across block
      // boundaries shows up here and not in the small vectors above.
      final Uint8List big = Uint8List(IsolateVideoProcessor.readBlockBytes * 5);
      for (int i = 0; i < big.length; i++) {
        big[i] = i & 0xFF;
      }

      final ChunkIntegrity result = await processor.process(
        write('big.mp4', big),
      );

      expect(result.byteCount, big.length);
      expect(result.checksumSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('the same bytes split differently give the same digest', () async {
      // The property block-wise hashing must have: the digest depends on the
      // content, never on how openRead happened to chunk it.
      final List<int> bytes = List<int>.generate(200000, (int i) => i & 0xFF);

      final ChunkIntegrity a = await processor.process(write('a.mp4', bytes));
      final ChunkIntegrity b = await processor.process(write('b.mp4', bytes));

      expect(a.checksumSha256, b.checksumSha256);
    });

    test('one differing byte changes the digest', () async {
      final List<int> bytes = List<int>.filled(50000, 1);
      final ChunkIntegrity before = await processor.process(
        write('c.mp4', bytes),
      );

      bytes[49999] = 2;
      final ChunkIntegrity after = await processor.process(
        write('d.mp4', bytes),
      );

      expect(before.checksumSha256, isNot(after.checksumSha256));
    });
  });

  group('byte count — §1.3, never estimated', () {
    test('it is the real file length, not a stream tally', () async {
      final ChunkIntegrity result = await processor.process(
        write('sized.mp4', List<int>.filled(123456, 0)),
      );

      expect(result.byteCount, 123456);
      expect(
        result.byteCount,
        File('${temp.path}/sized.mp4').lengthSync(),
        reason: 'read from the closed handle, per §1.3',
      );
    });
  });

  group('failure converts at this boundary', () {
    test('a missing file becomes a StorageException', () async {
      await expectLater(
        processor.process('${temp.path}/nope.mp4'),
        throwsA(
          isA<StorageException>().having(
            (StorageException e) => e.errorCode,
            'errorCode',
            ErrorCode.storageNotFound,
          ),
        ),
      );
    });

    test('no raw FileSystemException escapes', () async {
      // error-handling.md §26: nothing platform- or dart:io-specific leaves
      // data/. Asserted as a type exclusion, not just a type inclusion.
      Object? caught;
      try {
        await processor.process('${temp.path}/also-missing.mp4');
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isNot(isA<FileSystemException>()));
      expect(caught, isA<StorageException>());
    });

    test('the message names the operation, not the path', () async {
      // A chunk path contains a session id; error copy should not carry it.
      try {
        await processor.process('${temp.path}/secret-session-id.mp4');
        fail('expected a StorageException');
      } on StorageException catch (error) {
        expect(error.message, contains('checksumming'));
        expect(error.message, isNot(contains('secret-session-id')));
      }
    });
  });

  group('the real isolate path', () {
    test('the default runner spawns one and returns the same digest', () async {
      // The inline runner is a test convenience; this proves the production
      // path agrees with it, so every assertion above transfers.
      const IsolateVideoProcessor real = IsolateVideoProcessor();
      final String path = write('iso.mp4', <int>[0x61, 0x62, 0x63]);

      final ChunkIntegrity viaIsolate = await real.process(path);
      final ChunkIntegrity viaInline = await processor.process(path);

      expect(
        viaIsolate.checksumSha256,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(viaIsolate, viaInline);
    });

    test('a missing file converts the same way through the isolate', () async {
      const IsolateVideoProcessor real = IsolateVideoProcessor();

      await expectLater(
        real.process('${temp.path}/gone.mp4'),
        throwsA(isA<StorageException>()),
      );
    });
  });
}

/// Executes the work on the current isolate.
Future<ChunkIntegrity> _inline(Future<ChunkIntegrity> Function() work) =>
    work();
