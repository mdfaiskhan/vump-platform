import 'package:flutter/material.dart';

import 'package:mobile/app/theme/app_status_colors.dart';
import 'package:mobile/core/queue/chunk_upload_status.dart';

/// Chapter 2.8 §6's status pill, for one of Chapter 5.9 §1's four states.
///
/// ## Colour is never the only signal — Chapter 2.10 §2.1
///
/// *"Every status pill … pairs its color with both an icon and a text label. A
/// Collector with red-green color blindness must be able to tell 'Failed' from
/// 'Complete' from the label and icon shape alone, with zero reliance on
/// hue."*
///
/// So all three are mandatory here and none is optional: the icon and the
/// label are chosen to differ in shape and in word, not only in colour.
/// `complete` takes a check and `failed` a cross — the two the rule names
/// explicitly — while `queued` takes a clock and `uploading` an upward arrow.
///
/// The label is never abbreviated to fit. Chapter 2.7 requires the queued pill
/// to *"always read 'Queued', never left to color alone"*, and the same
/// applies to the other three.
class ChunkStatusPill extends StatelessWidget {
  /// Creates a pill for [status].
  const ChunkStatusPill({
    required this.status,
    this.percent,
    this.retryIn,
    super.key,
  });

  /// Which of Chapter 5.9 §1's four states to render.
  final ChunkUploadStatus status;

  /// Chapter 2.7's *"live percentage"*, shown inside an uploading pill.
  ///
  /// Null while the transfer has not reported yet, or when the total size is
  /// unknown — in which case the pill reads "Uploading" without a number
  /// rather than inventing one.
  final int? percent;

  /// How long until Chapter 5.13 §2's backoff allows the next attempt.
  ///
  /// Non-null only on a queued chunk that is waiting one out. Chapter 2.9 §4.3
  /// requires that *"a failed upload never silently retries in a way the
  /// Collector can't see"*, and this is what makes the retry visible — see
  /// A-091.
  final Duration? retryIn;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors palette = Theme.of(
      context,
    ).extension<AppStatusColors>()!;
    final _PillStyle style = _styleFor(status, palette);

    return Semantics(
      // The visual label already carries the state; this adds the retry detail
      // for a screen reader, which cannot see the countdown's placement.
      label: _semanticLabel(),
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.fill,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(style.icon, size: 14, color: style.foreground),
              const SizedBox(width: 6),
              Text(
                _label(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The visible word, with Chapter 2.7's percentage folded in when there is
  /// one.
  String _label() {
    switch (status) {
      case ChunkUploadStatus.queued:
        return retryIn == null ? 'Queued' : 'Retrying in ${_short(retryIn!)}';
      case ChunkUploadStatus.uploading:
        return percent == null ? 'Uploading' : 'Uploading $percent%';
      case ChunkUploadStatus.failed:
        return 'Failed';
      case ChunkUploadStatus.complete:
        return 'Complete';
    }
  }

  String _semanticLabel() {
    final String base = _label();
    if (status == ChunkUploadStatus.failed) {
      return '$base. Retry available.';
    }
    return base;
  }

  /// A countdown a Collector can read at a glance, not a duration dump.
  static String _short(Duration left) {
    if (left.inSeconds < 60) {
      return '${left.inSeconds}s';
    }
    return '${left.inMinutes}m';
  }

  static _PillStyle _styleFor(
    ChunkUploadStatus status,
    AppStatusColors palette,
  ) {
    switch (status) {
      case ChunkUploadStatus.queued:
        // Warning hue — Chapter 2.7's "Warning-hue pill".
        return _PillStyle(
          palette.warning,
          palette.onWarning,
          Icons.schedule_outlined,
        );
      case ChunkUploadStatus.uploading:
        // Accent hue — Chapter 2.7's "Accent-hue pill with live percentage".
        return _PillStyle(
          palette.accent,
          palette.onAccent,
          Icons.arrow_upward_rounded,
        );
      case ChunkUploadStatus.failed:
        return _PillStyle(
          palette.critical,
          palette.onCritical,
          Icons.close_rounded,
        );
      case ChunkUploadStatus.complete:
        return _PillStyle(palette.good, palette.onGood, Icons.check_rounded);
    }
  }
}

class _PillStyle {
  const _PillStyle(this.fill, this.foreground, this.icon);

  final Color fill;
  final Color foreground;
  final IconData icon;
}
