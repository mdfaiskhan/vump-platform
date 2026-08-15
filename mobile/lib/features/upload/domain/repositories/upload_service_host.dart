/// The OS-level service that keeps an upload alive, as Chapter 5.11 needs it.
///
/// Volume 5 Chapter 5.11 §3 scopes the whole chapter narrowly: it *"only owns
/// keeping the OS from killing the attempt outright while a connection
/// exists"*. This port is that one job, and nothing else — it does not upload,
/// does not read the queue, and does not decide when to run.
///
/// ## Why a port rather than a direct call
///
/// `flutter_foreground_task` is confined to `features/upload/data/` by the
/// `Architecture boundaries` CI job, the same way ADR-034 confines a Firebase
/// *product* to the module that consumes it. `UploadDispatcher` lives in
/// `application/` and may not import `data/` (ADR-022 §5.3), so the
/// requirement is stated here and the composition root introduces the two.
///
/// That is also what makes the dispatcher testable: Chapter 5.11 §1's service
/// lifecycle rules are assertions about *when* these methods are called, and a
/// fake host records calls without a platform channel.
///
/// ## Android only, deliberately
///
/// Chapter 5.11 §2 specifies iOS as a background `URLSession`, which is a
/// different mechanism with a different lifecycle — the app *"does not attempt
/// to keep itself alive artificially"*. This contract describes the Android
/// shape and would be the wrong abstraction to force iOS through. Open item 22
/// records that no iOS toolchain exists to build or verify one against.
abstract interface class UploadServiceHost {
  /// Starts the service and shows §1's persistent notification.
  ///
  /// Called when the first chunk reaches `uploading`, and **not once per
  /// chunk** — §1 requires a single service that *"stays alive as long as the
  /// queue has anything left to send … to avoid repeated notification
  /// flicker"*. Calling it while already running is a no-op.
  ///
  /// [title] and [text] are the notification's two lines. [text] carries
  /// `UploadBatchProgress.notificationText`.
  ///
  /// Returns false when the service could not be started — most often because
  /// notification permission was refused on Android 13+. The caller keeps
  /// uploading regardless: a missing notification is a visibility failure, not
  /// a reason to stop transferring bytes the Collector already recorded.
  Future<bool> start({required String title, required String text});

  /// Rewrites the running notification's text.
  ///
  /// The aggregate in §1 changes as chunks finish, and this is how — not by
  /// stopping and restarting the service, which is the flicker §1 names.
  ///
  /// Does nothing when the service is not running.
  Future<void> update({required String title, required String text});

  /// Stops the service and removes the notification.
  ///
  /// §1 makes the notification *"dismissible only once the queue is fully
  /// drained or every remaining item is Failed awaiting manual retry"*. On
  /// Android that dismissibility is not a flag this application can set — a
  /// running foreground service owns its notification, and from Android 14 the
  /// user may swipe it away regardless. So the enforceable reading is that the
  /// notification goes away **when the service stops**, and the dispatcher
  /// stops it exactly at §1's two conditions.
  ///
  /// Does nothing when the service is not running.
  Future<void> stop();

  /// Whether the service is currently running.
  Future<bool> isRunning();
}
