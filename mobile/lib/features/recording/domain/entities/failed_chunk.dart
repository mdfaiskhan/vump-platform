import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mobile/core/errors/error_codes.dart';

part 'failed_chunk.freezed.dart';

/// A chunk whose background processing failed terminally.
///
/// Chapter 5.13 §1 classifies *"Local file missing/corrupted, disk full"* as
/// **Terminal (device-side)**, handled as *"Not retried automatically —
/// surfaces immediately as Failed with a specific, named cause"*. A checksum
/// that cannot be computed is that class of failure, so the chunk is marked
/// and the session carries on.
///
/// ## Why the machine records this instead of stopping
///
/// Before Mission 3.4.5 a failed finalization parked the whole lifecycle,
/// because capture could not continue past it anyway. Now it can, and Chapter
/// 5.13 §1 puts the outcome on the chunk rather than on the session — a Failed
/// chunk waits for the Collector's Retry (C-11, FR-UPL-07), it does not end
/// their recording. Stopping a live capture because an earlier chunk's hash
/// failed would destroy footage that is still being recorded correctly.
///
/// ## This is a hand-off, not a home
///
/// Durable per-chunk status belongs to the Upload Queue and its Isar records
/// (Chapters 5.8, 5.9 — Mission 3.7), and C-11 renders it from there. This
/// type exists so that between a failure and that mission, a failed chunk is
/// still *somewhere* rather than silently dropped when its job leaves the
/// pending set.
@freezed
class FailedChunk with _$FailedChunk {
  /// Records a terminal processing failure.
  const factory FailedChunk({
    /// The chunk's stable id, unchanged by the failure (Ch. 5.13 §4).
    required String chunkId,

    /// Its position within the session.
    required int sequenceIndex,

    /// The named cause Chapter 2.9's copy rules require.
    required ErrorCode cause,
  }) = _FailedChunk;
}
