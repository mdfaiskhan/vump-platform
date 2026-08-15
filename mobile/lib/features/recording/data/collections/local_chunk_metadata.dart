import 'package:isar/isar.dart';

import 'package:mobile/features/recording/data/collections/embedded/embedded_capture.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_capture_conditions.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_collector_authored.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_device_context.dart';
// Imported for its generated schema, which the part file below references even
// though this file names only the group that nests it.
import 'package:mobile/features/recording/data/collections/embedded/embedded_gps_fix.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_identity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_integrity.dart';
import 'package:mobile/features/recording/data/collections/embedded/embedded_timing.dart';

part 'local_chunk_metadata.g.dart';

/// Volume 5 Chapter 5.8 §1's `local_chunk_metadata` table.
///
/// §1 requires *"Identical field shape to Volume 4, Chapter 4.5's JSON"*, and
/// that JSON is nested into seven groups. So this is stored **embedded rather
/// than flattened** — `EmbeddedIdentity`, `EmbeddedTiming` and the rest mirror
/// the groups one for one.
///
/// Flattening would have been easier to write and wrong for the same reason
/// Mission 3.6 kept the groups as types: Chapter 4.5 §2 notes the group names
/// *"match the ones Volume 1, Chapter 1.3 already used, so there is no
/// re-labeling between requirement and implementation"*. A flat row of
/// twenty-one columns is that relabeling, and it would have to be un-flattened
/// again on upload to produce the wire format.
///
/// ## One row per chunk, keyed by the chunk
///
/// Volume 4 Chapter 4.4 §7 makes `chunk_metadata.chunk_id` both primary key
/// and foreign key — 1:1 with `chunks`. [chunkId] is indexed unique here for
/// the same reason, and it is what the atomic write pairs on.
@collection
class LocalChunkMetadata {
  /// Creates a stored metadata record.
  LocalChunkMetadata();

  /// Isar's surrogate key.
  Id id = Isar.autoIncrement;

  /// The chunk this describes — 1:1, per Volume 4 Chapter 4.4 §7.
  @Index(unique: true, replace: true)
  late String chunkId;

  /// `identity` — session, project, task, collector, device.
  EmbeddedIdentity? identity;

  /// `timing` — sequence index and the two capture timestamps.
  EmbeddedTiming? timing;

  /// `capture` — the fixed parameters plus the resolved zoom factor.
  EmbeddedCapture? capture;

  /// `device_context` — model, OS version, app version.
  EmbeddedDeviceContext? deviceContext;

  /// `capture_conditions` — GPS, battery, network. Absent today by design.
  EmbeddedCaptureConditions? captureConditions;

  /// `integrity` — checksum and byte count.
  EmbeddedIntegrity? integrity;

  /// `collector_authored` — the only mutable group (Ch. 4.5 §4).
  EmbeddedCollectorAuthored? collectorAuthored;
}
