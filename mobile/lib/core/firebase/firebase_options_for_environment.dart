/// Selects the generated Firebase options for the environment this build
/// targets — ADR-047.
///
/// Three `flutterfire configure` runs produce three option files, one per
/// Firebase project. Each declares a class called `DefaultFirebaseOptions`,
/// so they are imported under prefixes; the names collide by construction
/// because the generator does not know the others exist.
///
/// ## Why a selector exists at all on Android
///
/// On Android the `com.google.gms.google-services` plugin already reads
/// `src/{flavor}/google-services.json`, so `Firebase.initializeApp()` with no
/// arguments would resolve the right project by itself. The options are still
/// passed explicitly for two reasons, and neither is a cross-check — nothing
/// here can read the native configuration to compare against it.
///
/// The first is that the Dart side stays self-describing: the project a build
/// targets is decided by code that can be read and tested, not only by which
/// file Gradle happened to copy. The second is that `firebase_initializer.dart`
/// logs `app.options.projectId` at startup, so the project actually in use is
/// stated in the first line of any diagnostic report. That log line is what
/// makes a flavor/selector disagreement observable, and it is what the live
/// device check reads.
///
/// ## Platforms
///
/// Android and iOS only. The three new projects have Android and iOS apps
/// registered and nothing else, because those are the platforms this product
/// ships to. Web, Windows and macOS resolve to a [UnsupportedError] with the
/// environment named, rather than to a default that would silently be the
/// wrong project.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/firebase/firebase_options_dev.dart' as dev;
import 'package:mobile/core/firebase/firebase_options_prod.dart' as prod;
import 'package:mobile/core/firebase/firebase_options_staging.dart' as staging;

/// The Firebase project this build talks to.
///
/// Resolved from [AppConfig.environment], which ADR-047 derives from the build
/// flavor — the same flavor that selected the native configuration file.
FirebaseOptions firebaseOptionsForEnvironment(AppEnvironment environment) {
  return switch (environment) {
    AppEnvironment.development => dev.DefaultFirebaseOptions.currentPlatform,
    AppEnvironment.staging => staging.DefaultFirebaseOptions.currentPlatform,
    AppEnvironment.production => prod.DefaultFirebaseOptions.currentPlatform,
  };
}

/// The options for the environment this binary was compiled for.
FirebaseOptions get currentFirebaseOptions =>
    firebaseOptionsForEnvironment(AppConfig.environment);
