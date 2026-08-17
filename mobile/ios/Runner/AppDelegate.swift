import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerFreeSpaceChannel(engineBridge.binaryMessenger)
  }

  /// Reports free bytes on the volume holding a given path.
  ///
  /// The iOS half of the channel Volume 5 Chapter 5.4 §2 needs — see
  /// `FreeSpaceChannel.kt` for why this is a channel rather than a package.
  ///
  /// **Uses `volumeAvailableCapacityForImportantUsageKey`, not
  /// `volumeAvailableCapacity`.** Apple recommends the former for exactly this
  /// question: it reports what is available for resources the app genuinely
  /// needs, which includes space the system can reclaim by purging caches. The
  /// cruder key under-reports and would force early chunk boundaries on a
  /// device that has room.
  ///
  /// **UNVERIFIED ON HARDWARE.** This project has no Mac, no iOS device and no
  /// iOS Firebase configuration, so this branch has never executed. Recorded as
  /// open against the Volume 9 device-matrix follow-up, alongside the encoder
  /// checks in amendment A-058 — not presented as working.
  private func registerFreeSpaceChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "vump/free_space",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "availableBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_PATH",
            message: "availableBytes requires a non-empty 'path'.",
            details: nil
          )
        )
        return
      }

      do {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(
          forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        guard let available = values.volumeAvailableCapacityForImportantUsage else {
          result(
            FlutterError(
              code: "STAT_FAILED",
              message: "The volume reported no available capacity value.",
              details: nil
            )
          )
          return
        }
        // Int64 crosses the channel as a Dart int. No floating point.
        result(NSNumber(value: available))
      } catch {
        result(
          FlutterError(
            code: "STAT_FAILED",
            message: "Could not read volume capacity for the given path.",
            details: error.localizedDescription
          )
        )
      }
    }
  }
}
