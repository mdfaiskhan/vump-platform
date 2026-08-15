import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/upload/domain/entities/upload_dispatcher_status.dart';

/// Publishes whether Chapter 5.11's dispatcher can run, for C-11 to render.
///
/// The dispatcher itself stays framework-free — it reports through a callback
/// and knows nothing about Riverpod or about a screen. This notifier is the
/// bridge, wired in `uploadDispatcherProvider` exactly as progress reporting
/// is.
///
/// Once halted, it stays halted. Both faults that reach here are
/// unrecoverable without a restart: a pipeline that cannot be constructed will
/// not construct on the next attempt, and the queue subscription is not
/// re-established. Flipping back to `running` would be a lie that the retry
/// button could not cash.
class UploadDispatcherStatusNotifier extends Notifier<UploadDispatcherStatus> {
  @override
  UploadDispatcherStatus build() => UploadDispatcherStatus.running;

  /// Records that the dispatcher stopped on a fault.
  void markHalted() {
    if (state == UploadDispatcherStatus.halted) {
      return;
    }
    state = UploadDispatcherStatus.halted;
  }
}

/// Whether uploads are running at all — watched by C-11.
final NotifierProvider<UploadDispatcherStatusNotifier, UploadDispatcherStatus>
uploadDispatcherStatusProvider =
    NotifierProvider<UploadDispatcherStatusNotifier, UploadDispatcherStatus>(
      UploadDispatcherStatusNotifier.new,
    );
