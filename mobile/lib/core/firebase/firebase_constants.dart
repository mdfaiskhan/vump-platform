/// Fixed values for Firebase initialisation.
///
/// Contains no key, identifier or credential. Project identifiers live in
/// `firebase_options.dart`, which is generated; secrets live nowhere in source
/// at all, per ADR-007.
abstract final class FirebaseConstants {
  /// Name Firebase gives the primary application instance.
  ///
  /// Every product plugin — Auth, Crashlytics, Analytics, Messaging — attaches
  /// to this instance unless told otherwise. Fixed by the Firebase SDK; it is
  /// named here so no call site spells it as a literal.
  static const String defaultAppName = '[DEFAULT]';

  /// Time allowed for initialisation before it is abandoned.
  ///
  /// Initialisation is on the startup path and talks to platform channels. An
  /// unbounded wait turns a misconfigured build into an application that hangs
  /// on a blank screen, which is far harder to diagnose than a clean failure.
  static const Duration initializationTimeout = Duration(seconds: 20);
}
