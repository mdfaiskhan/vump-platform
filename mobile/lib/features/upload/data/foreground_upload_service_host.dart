import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:mobile/features/upload/domain/repositories/upload_service_host.dart';

/// Volume 5 Chapter 5.11 §1's Android foreground service.
///
/// Volume 3 Chapter 3.1 §2 names the package: *"a foreground service
/// (flutter_foreground_task) driving Dio multipart uploads, with a persistent,
/// dismissible-only-on-completion notification"*. This class is the only place
/// in the application that imports it.
///
/// ## The service keeps the process alive; it does not run the upload
///
/// `flutter_foreground_task` runs its `TaskHandler` in a **separate Dart
/// isolate**, reachable only by primitives, `String` and `Map`/`List`. The
/// upload pipeline cannot live there: it needs the single `IsarChunkStore`
/// instance ADR-040 requires C-11, the finalizer and the pipeline to share,
/// the `ProviderContainer`, and — through `AuthInterceptor` (ADR-035) — a
/// `firebase_auth` token, which the SDK does not serve from a background
/// isolate.
///
/// So the upload runs in the **main** isolate, which the foreground service
/// keeps alive by keeping the process alive. The task isolate does nothing but
/// exist, because the plugin requires a handler to start a service at all.
/// Recorded as ADR-042.
///
/// This is why [_UploadNotificationTaskHandler] is empty. It is not a stub
/// awaiting work: under this design there is no work for it to do, and moving
/// work into it would break the single-instance guarantee ADR-040 rests on.
///
/// ## The wake lock is held for the service's whole life
///
/// §1 asks for a partial wake lock *"only while actively transferring bytes —
/// not for its entire lifetime"*. `allowWakeLock` is a `ForegroundTaskOptions`
/// field fixed when the service starts; toggling it per transfer means calling
/// `updateService` around every chunk, which re-enters the notification
/// flicker §1 explicitly wants avoided, to save power only during the gaps
/// between chunks in a queue the dispatcher is actively draining.
///
/// The lock is therefore held for the service's active life, and the service's
/// life is bounded by the drain rather than by the app's. Amendment A-079
/// records the divergence and the reasoning.
class ForegroundUploadServiceHost implements UploadServiceHost {
  /// Distinguishes this service from any other this app may later run.
  static const int _serviceId = 5110;

  bool _initialised = false;

  @override
  Future<bool> start({required String title, required String text}) async {
    if (await isRunning()) {
      // §1: one service for the whole queue, "not restarted per chunk".
      return true;
    }

    _initialise();

    // Android 13+ hides the notification without this, and §1's whole purpose
    // is that the work is visible. Asked here rather than at app launch: a
    // permission prompt makes sense at the moment the thing it protects is
    // about to happen, not during a splash screen.
    final NotificationPermission permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: <ForegroundServiceTypes>[
            ForegroundServiceTypes.dataSync,
          ],
          notificationTitle: title,
          notificationText: text,
          callback: startUploadServiceIsolate,
        );

    return result is ServiceRequestSuccess;
  }

  @override
  Future<void> update({required String title, required String text}) async {
    if (!await isRunning()) {
      return;
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  @override
  Future<void> stop() async {
    if (!await isRunning()) {
      return;
    }
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  /// Configures the notification channel and the service's options.
  ///
  /// Idempotent, and called at the first start rather than at app launch:
  /// `init` is pure configuration with no platform call behind it, and doing
  /// it here keeps every decision about the service in one file.
  void _initialise() {
    if (_initialised) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vump_upload',
        channelName: 'Chunk upload',
        channelDescription:
            'Shows progress while recorded chunks upload in the background.',
        // LOW keeps the notification silent and un-intrusive. Chapter 2.9 §2
        // principle 3 requires background work to stay *visible*, which this
        // satisfies; it does not ask for it to interrupt, and a Collector
        // mid-walkthrough does not need a chime per chunk.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        // The text changes on every chunk. Without this, each update would
        // re-alert.
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Nothing is scheduled in the task isolate, so there is no repeat
        // event to fire. See the class comment: the isolate exists because the
        // plugin requires one, not because work runs there.
        eventAction: ForegroundTaskEventAction.nothing(),
        // Both false: the service exists to finish a drain the app started,
        // and a service resurrected at boot would have no dispatcher driving
        // it. Chapter 5.9 §3 already guarantees nothing is lost — the rows
        // still say `queued` and the next launch reads them.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // See the class comment and A-079.
        allowWakeLock: true,
        // Not enabled. Chapter 5.11 defers connectivity entirely to Chapter
        // 5.12, and holding a Wi-Fi lock would be this chapter taking a
        // decision about the radio that Chapter 5.12 owns.
        allowWifiLock: false,
      ),
    );

    _initialised = true;
  }
}

/// The task isolate's entry point.
///
/// Must be top-level and annotated so release-mode tree shaking cannot remove
/// it — the plugin resolves it by pointer across an isolate boundary, so
/// nothing in this program appears to call it.
///
/// It installs a handler that does nothing. See
/// [ForegroundUploadServiceHost]'s comment for why that is the design rather
/// than an omission.
@pragma('vm:entry-point')
void startUploadServiceIsolate() {
  FlutterForegroundTask.setTaskHandler(_UploadNotificationTaskHandler());
}

/// A handler that exists so the service can start, and does nothing else.
///
/// Every upload decision is made in the main isolate by `UploadDispatcher`.
/// Private so nothing can grow work onto it from elsewhere: adding work here
/// would need a second Isar connection and a second provider container, which
/// is exactly what ADR-042 decided against.
class _UploadNotificationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
