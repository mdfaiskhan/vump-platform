import 'package:isar/isar.dart';

part 'embedded_identity.g.dart';

/// The `identity` group of Volume 4 Chapter 4.5's schema, on disk.
///
/// Every field is nullable here although the domain type requires all five.
/// Isar needs a default constructor and mutable fields, and a record written
/// by an older build must still be readable — so the storage shape is
/// permissive and the mapper is where the domain's requirements are enforced.
@embedded
class EmbeddedIdentity {
  /// Creates a stored EmbeddedIdentity.
  EmbeddedIdentity();

  /// The session UUID this chunk belongs to.
  String? sessionId;

  /// From `TaskContext`. Null until `features/projects_tasks/` exists.
  String? projectId;

  /// From `TaskContext`. Null for the same reason as [projectId].
  String? taskId;

  /// From `DeviceContext` — auth's `User.uid`, inverted per ADR-022 R3.
  String? collectorId;

  /// Chapter 5.7 §2's "cached, stable device identifier". Undecided.
  String? deviceId;
}
