import 'dart:math' as math;

/// The aggregate Volume 5 Chapter 5.11 §1's notification shows.
///
/// The chapter asks for *"aggregate progress (\"Uploading 2 of 5 chunks\")"* —
/// one number pair for the whole queue, not one notification per chunk. This
/// is that pair, and it is a value type rather than a counter inside the
/// dispatcher so the arithmetic can be tested without a service, a database or
/// a platform channel.
///
/// ## Why it carries memory at all
///
/// A denominator cannot be read off the current queue rows. `complete` rows
/// persist until Chapter 5.15's cleanup runs, so counting them would inflate
/// "of 5" with every chunk the device has ever uploaded; counting only
/// outstanding rows would make the denominator shrink as work finished, so the
/// Collector would watch "1 of 5" become "1 of 4" and never see progress.
///
/// So the batch remembers the high-water mark of work it has seen since it
/// started, and [observe] moves it forward. That is the smallest amount of
/// memory that makes the sentence in §1 true.
///
/// ## The batch resets when the queue drains, and that is Chapter 5.11 §1
///
/// §1 requires one service that *"stays alive as long as the queue has
/// anything left to send — not restarted per chunk, to avoid repeated
/// notification flicker"*. A batch therefore spans every chunk uploaded
/// between one drain and the next, however many sessions those chunks came
/// from. Reaching zero outstanding work returns [idle], which is what ends the
/// batch — and a chunk arriving afterwards starts a new one.
///
/// Chunks that arrive *during* a batch join it: the denominator grows rather
/// than a second batch starting alongside the first.
final class UploadBatchProgress {
  const UploadBatchProgress._({required this.total, required this.remaining});

  /// Nothing outstanding — no batch is running.
  ///
  /// Both the starting state and the state a drained batch returns to.
  static const UploadBatchProgress idle = UploadBatchProgress._(
    total: 0,
    remaining: 0,
  );

  /// Every chunk this batch has been asked to send, including those finished.
  ///
  /// The denominator in §1's sentence. Never decreases within a batch.
  final int total;

  /// How many of [total] are still `queued` or `uploading`.
  final int remaining;

  /// How many of [total] have reached a terminal state within this batch.
  ///
  /// Terminal means Chapter 5.9 §1's `complete` or `failed`. A failed chunk
  /// counts as done here because §1 lets the notification be dismissed when
  /// *"every remaining item is Failed awaiting manual retry"* — a batch that
  /// waited for failures to succeed would never end.
  int get done => total - remaining;

  /// Whether the batch has finished — §1's *"queue is fully drained"*.
  bool get isIdle => remaining == 0;

  /// The numerator in §1's sentence: which chunk is being worked on now.
  ///
  /// One-based, because it is read by a person. Clamped to [total] so a
  /// drained batch never claims to be on a chunk that does not exist.
  int get position => isIdle ? total : done + 1;

  /// Folds the current outstanding count into the batch.
  ///
  /// [outstanding] is the number of rows sitting in `queued` or `uploading` —
  /// the work Chapter 5.11's dispatcher still owes. It is the only input,
  /// because it is the only quantity the queue can answer without knowing what
  /// any previous batch did.
  ///
  /// Returns [idle] when nothing is outstanding, which closes the batch.
  UploadBatchProgress observe(int outstanding) {
    if (outstanding <= 0) {
      return idle;
    }
    return UploadBatchProgress._(
      total: math.max(total, outstanding + done),
      remaining: outstanding,
    );
  }

  /// §1's notification body, in Chapter 2.9 §3's voice.
  ///
  /// Chapter 2.9 §3 requires copy *"a first-time Collector in the field
  /// wouldn't"* have to decode, which is why the singular case is spelled out
  /// rather than rendered as "1 chunks".
  String get notificationText {
    if (isIdle) {
      return 'No chunks are waiting to upload.';
    }
    if (total == 1) {
      return 'Uploading 1 chunk.';
    }
    return 'Uploading $position of $total chunks.';
  }

  @override
  String toString() => 'UploadBatchProgress($position/$total)';

  @override
  bool operator ==(Object other) =>
      other is UploadBatchProgress &&
      other.total == total &&
      other.remaining == remaining;

  @override
  int get hashCode => Object.hash(total, remaining);
}
