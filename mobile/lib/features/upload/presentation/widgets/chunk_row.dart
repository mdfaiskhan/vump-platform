import 'package:flutter/material.dart';

import 'package:mobile/app/theme/app_status_colors.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';
import 'package:mobile/core/queue/queued_chunk.dart';
import 'package:mobile/features/upload/domain/entities/chunk_upload_progress_snapshot.dart';
import 'package:mobile/features/upload/presentation/widgets/chunk_status_pill.dart';

/// One chunk row of Chapter 2.7's C-11.
///
/// Chapter 2.7 fixes the layout precisely:
///
/// - uploading — *"Accent-hue pill with live percentage; progress bar beneath
///   the row, **not inside the pill**"*
/// - failed — *"row gets a critical-colored border … expands to reveal a
///   btn-secondary 'Retry Chunk' action"*
/// - complete — *"row is otherwise inert once complete — no action needed"*
/// - queued — a warning-hue pill and nothing else
///
/// ## The failed row cannot name its cause, and says so by omission
///
/// Chapter 2.9 §2 principle 1 wants the specific cause, and this row shows
/// only "Failed" plus the retry. `local_chunks` stores a status but no failure
/// cause, so there is nothing to render — open item 53. Inventing a generic
/// sentence here would be the *"Something went wrong"* Chapter 2.9 §2 calls a
/// defect, so the row stays silent about *why* rather than guessing.
class ChunkRow extends StatelessWidget {
  /// Creates a row for [chunk].
  const ChunkRow({
    required this.chunk,
    required this.now,
    this.progress,
    this.onRetry,
    super.key,
  });

  /// The queue row to render.
  final QueuedChunk chunk;

  /// The instant the countdown is measured against.
  ///
  /// Passed in rather than read here, for A-045's reason: a widget that called
  /// `DateTime.now()` could not be tested without waiting out a real backoff.
  final DateTime now;

  /// Live transfer progress, when this chunk is uploading.
  final ChunkUploadProgressSnapshot? progress;

  /// FR-UPL-07's Retry Chunk action. Null disables the button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors palette = Theme.of(
      context,
    ).extension<AppStatusColors>()!;
    final bool isFailed = chunk.status == ChunkUploadStatus.failed;
    final bool isUploading = chunk.status == ChunkUploadStatus.uploading;
    final bool awaitingRetry = chunk.isAwaitingRetry(now);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        // Chapter 2.7: a failed row "gets a critical-colored border". Only a
        // failed row does — a border on every row would make the failure
        // ordinary.
        border: isFailed
            ? Border.all(color: palette.critical, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Chunk ${chunk.sequenceIndex + 1}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ChunkStatusPill(
                  status: chunk.status,
                  percent: isUploading ? progress?.percent : null,
                  retryIn: awaitingRetry
                      ? chunk.nextAttemptAt!.difference(now)
                      : null,
                ),
              ],
            ),
            if (isUploading) ...<Widget>[
              const SizedBox(height: 8),
              // "progress bar beneath the row, not inside the pill".
              // An unknown total renders indeterminate rather than as 0%.
              LinearProgressIndicator(
                value: progress?.fraction,
                color: palette.accent,
                backgroundColor: palette.accent.withValues(alpha: 0.18),
              ),
            ],
            if (isFailed) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Retry Chunk'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
