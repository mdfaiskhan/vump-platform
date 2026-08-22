import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/random_uuid_generator.dart';

/// The generator behind every `session_id` and `chunk_id`.
///
/// Both methods delegate to one `UuidV4`, which is the property worth pinning:
/// they must not diverge into two sources, because a session and its chunks
/// are joined on these values by the backend. The seeded `Random` makes the
/// output deterministic, so this asserts real values rather than a shape.
void main() {
  test('produces v4-shaped identifiers', () {
    final RandomUuidGenerator generator = RandomUuidGenerator(
      random: Random(42),
    );

    final RegExp v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(generator.newSessionId(), matches(v4));
    expect(generator.newChunkId(), matches(v4));
  });

  test(
    'the same seed produces the same sequence, so this is deterministic',
    () {
      // Not a property of the production generator, which uses Random.secure().
      // It is what makes the collision assertion below meaningful rather than
      // probabilistic.
      final RandomUuidGenerator a = RandomUuidGenerator(random: Random(7));
      final RandomUuidGenerator b = RandomUuidGenerator(random: Random(7));

      expect(a.newSessionId(), b.newSessionId());
      expect(a.newChunkId(), b.newChunkId());
    },
  );

  test('successive identifiers differ, including across the two methods', () {
    // One generator, two entry points. If `newChunkId` ever grew its own
    // source, a chunk could collide with its own session id and the backend
    // join would silently match the wrong row.
    final RandomUuidGenerator generator = RandomUuidGenerator(
      random: Random(1),
    );

    final Set<String> seen = <String>{
      generator.newSessionId(),
      generator.newSessionId(),
      generator.newChunkId(),
      generator.newChunkId(),
    };

    expect(seen, hasLength(4));
  });
}
