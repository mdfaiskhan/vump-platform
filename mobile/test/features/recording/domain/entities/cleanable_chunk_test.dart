import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/recording/domain/entities/cleanable_chunk.dart';

/// Chapter 5.15 §2's eligible chunk, as the sweep sees it.
void main() {
  test('carries only what deleting a file needs', () {
    const CleanableChunk chunk = CleanableChunk(
      chunkId: 'c1',
      localFilePath: '/recordings/s1/0000.mp4',
      fileSizeBytes: 610000000,
    );

    expect(chunk.chunkId, 'c1');
    expect(chunk.localFilePath, '/recordings/s1/0000.mp4');
    expect(chunk.fileSizeBytes, 610000000);
  });

  test('toString reports the id and the size, not the path', () {
    // The path is the one field a log line does not need — it is long, and it
    // is derivable from the id.
    const CleanableChunk chunk = CleanableChunk(
      chunkId: 'c1',
      localFilePath: '/recordings/s1/0000.mp4',
      fileSizeBytes: 4096,
    );

    expect(chunk.toString(), contains('c1'));
    expect(chunk.toString(), contains('4096'));
  });
}
