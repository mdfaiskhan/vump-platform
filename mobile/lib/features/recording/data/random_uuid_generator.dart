import 'dart:math';

import 'package:mobile/core/identity/uuid_v4.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_id_generator.dart';
import 'package:mobile/features/recording/domain/repositories/session_id_generator.dart';

/// Mints the UUIDs Volume 5 Chapter 5.14 §3 requires, without a package.
///
/// ## The generation moved to `core/` — Mission 7.4, F23
///
/// `DeviceIdStore` needs a UUID too, and it is `core/` infrastructure belonging
/// to no feature. Rather than write RFC 4122 §4.4 twice, the minting lives in
/// `core/identity/UuidV4` and this class became the adapter over it.
///
/// **The two ports did not move with it**, and could not: they are
/// `features/recording/domain/` contracts, so a `core/` class implementing them
/// would be `core/` → `features/` — forbidden as firmly as the sideways import.
/// So the *source* is shared and the *ports* stay where their callers are.
///
/// ## One class, two ports
///
/// [SessionIdGenerator] and [ChunkIdGenerator] are separate interfaces because
/// their callers are separate and Chapter 5.13 §4's "never recomputed" rule
/// applies to one of them with particular force. The *source* of the bytes is
/// the same, so one implementation satisfies both rather than two files
/// differing only in a method name.
///
/// `Random.secure()` and the reasoning for it now live with the minter.
class RandomUuidGenerator implements SessionIdGenerator, ChunkIdGenerator {
  /// Creates a generator over [random], or a fresh secure source.
  RandomUuidGenerator({Random? random}) : _uuid = UuidV4(random: random);

  final UuidV4 _uuid;

  @override
  String newSessionId() => _uuid.next();

  @override
  String newChunkId() => _uuid.next();
}
