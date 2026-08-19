/// Mints RFC 4122 version-4 UUIDs, without a package.
///
/// ## Why this is in `core/` — Mission 7.4, F23
///
/// It was `features/recording/data/RandomUuidGenerator`, which was the right
/// home while recording was the only thing that needed an id. `DeviceIdStore`
/// needs one too, and it is `core/` infrastructure belonging to no feature —
/// so the generation moved here rather than being written a second time.
///
/// **The two recording ports did not move with it.** `SessionIdGenerator` and
/// `ChunkIdGenerator` are `features/recording/domain/` contracts, and a `core/`
/// class implementing them would be `core/` → `features/`, which ADR-022
/// forbids just as firmly as the sideways import. So this mints and knows
/// nothing about either port; `RandomUuidGenerator` stays where it is as a
/// thin adapter over it, satisfying both ports from this one source.
///
/// ## Why not the `uuid` package
///
/// It is not in this project's dependency tree, and admitting it under ADR-030
/// would buy about twenty lines. RFC 4122 §4.4's version-4 layout is sixteen
/// random bytes with six bits fixed — small enough to state exactly, and
/// stating it here means the format is visible next to the requirement it
/// satisfies rather than behind a package boundary.
///
/// Mission 3.8 added two dependencies for things the platform genuinely would
/// not answer (battery, connectivity). This is not one of those.
///
/// ## `Random.secure()`, not `Random()`
///
/// A session id ends up in an S3 object key (Chapter 5.14 §1), a chunk id is
/// the duplicate-prevention key BR-11 rests on, and a device id is the
/// correlator every chunk's metadata carries. None is a secret, but none may
/// collide — and the default PRNG is seeded from the clock, so two devices
/// starting a session in the same millisecond is an ordinary event in a fleet
/// rather than a remote one.
library;

import 'dart:math';

/// A source of version-4 UUIDs.
class UuidV4 {
  /// Creates a minter over [random], or a fresh secure source.
  UuidV4({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// One RFC 4122 version-4 UUID, lowercase, hyphenated.
  String next() {
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
