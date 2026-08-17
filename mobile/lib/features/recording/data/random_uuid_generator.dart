import 'dart:math';

import 'package:mobile/features/recording/domain/repositories/chunk_id_generator.dart';
import 'package:mobile/features/recording/domain/repositories/session_id_generator.dart';

/// Mints the UUIDs Volume 5 Chapter 5.14 §3 requires, without a package.
///
/// ## Why not `uuid`
///
/// `uuid` is not in this project's dependency tree, and admitting it under
/// ADR-030 would buy about twenty lines. RFC 4122 §4.4's version-4 layout is
/// sixteen random bytes with six bits fixed — small enough to state exactly,
/// and stating it here means the format is visible next to the requirement it
/// satisfies rather than behind a package boundary.
///
/// Mission 3.8 added two dependencies for things the platform genuinely would
/// not answer (battery, connectivity). This is not one of those.
///
/// ## One class, two ports
///
/// [SessionIdGenerator] and [ChunkIdGenerator] are separate interfaces because
/// their callers are separate and Chapter 5.13 §4's "never recomputed" rule
/// applies to one of them with particular force. The *source* of the bytes is
/// the same, so one implementation satisfies both rather than two files
/// differing only in a method name.
///
/// ## `Random.secure()`, not `Random()`
///
/// A session id ends up in an S3 object key (Chapter 5.14 §1) and a chunk id
/// is the duplicate-prevention key BR-11 rests on. Neither is a secret, but
/// both must not collide, and the default PRNG is seeded from the clock —
/// two devices starting a session in the same millisecond is an ordinary
/// event in a fleet, not a remote one.
class RandomUuidGenerator implements SessionIdGenerator, ChunkIdGenerator {
  /// Creates a generator over [random], or a fresh secure source.
  RandomUuidGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String newSessionId() => _uuidV4();

  @override
  String newChunkId() => _uuidV4();

  /// One RFC 4122 version-4 UUID, lowercase, hyphenated.
  String _uuidV4() {
    final List<int> bytes = List<int>.generate(
      16,
      (int _) => _random.nextInt(256),
      growable: false,
    );

    // §4.4: bits 12-15 of time_hi_and_version are the version (4), and the two
    // most significant bits of clock_seq_hi_and_reserved are the variant (10).
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex = bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
