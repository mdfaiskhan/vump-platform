plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vump.humanarchive"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vump.humanarchive"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ADR-047. One selector for the environment, not two.
    //
    // The flavor chosen here decides three things at once: which
    // `google-services.json` the `com.google.gms.google-services` plugin
    // reads from `src/{flavor}/`, which application ID is installed, and —
    // via Flutter's own `FLUTTER_APP_FLAVOR` define, which `--flavor` sets and
    // `appFlavor` reads — which `AppEnvironment` the Dart side resolves.
    //
    // Nothing passes `--dart-define=APP_ENV` alongside `--flavor`, because a
    // second selector is a second thing that can disagree. That is the exact
    // defect ADR-007 rejected for the base URL, applied to the environment
    // itself.
    //
    // The suffixes are what let dev, staging and production sit on one device
    // at the same time: three application IDs, so Android treats them as three
    // applications rather than as upgrades of each other.
    //
    // The visible name comes from `src/{flavor}/res/values/strings.xml` rather
    // than from `resValue`, so three installed copies are also tellable apart
    // in the launcher. AGP 9 disables the `resValues` build feature by default,
    // and a per-flavor resource file is the idiom that does not require
    // switching a build feature back on to name an application.
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
        }
        create("prod") {
            // No suffix. Production is the bare identifier, so the shipped
            // application ID never carries an environment marker.
            dimension = "environment"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
