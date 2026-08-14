allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ---------------------------------------------------------------------------
// Compatibility shim for isar_flutter_libs — see amendment A-029, ADR-009.
// ---------------------------------------------------------------------------
//
// isar_flutter_libs 3.1.0+1 was published in 2023 against AGP 7.3 and
// compileSdk 30. This project builds with AGP 9.0.1 / Gradle 9.1.0, which
// rejects it twice:
//
//   1. "Namespace not specified" — AGP 8+ requires every module to declare one.
//   2. 21 AAR metadata errors — its own transitive dependencies (for example
//      androidx.fragment 1.7.1) require compileSdk 34 or later.
//
// Both are patched below. Nothing else is touched.
//
// This is a BRIDGE, NOT A CURE. It keeps the documented engine (ADR-009)
// building while the engine decision is revisited. It does not make Isar
// maintained, and it does NOT address ADR-009's other recorded Android risk:
// 16 KB page size support, which Google Play requires and which these
// prebuilt native libraries predate. That remains unverified.
//
// Scoped to this one module BY NAME, deliberately. A blanket patch across all
// subprojects would silently absorb the next incompatible plugin instead of
// failing loudly and forcing a decision.
//
// Remove this block when the engine question in A-029 is resolved.
val modulesNeedingAgp8Shim = setOf("isar_flutter_libs")

subprojects {
    if (project.name in modulesNeedingAgp8Shim) {
        afterEvaluate {
            extensions.findByName("android")?.let { android ->
                val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                val setNamespace = android.javaClass.methods.firstOrNull { it.name == "setNamespace" }
                if (getNamespace != null && setNamespace != null && getNamespace.invoke(android) == null) {
                    setNamespace.invoke(android, project.group.toString())
                    logger.lifecycle("A-029 shim: namespace '${project.group}' -> ${project.name}")
                }

                val getCompileSdk = android.javaClass.methods.firstOrNull { it.name == "getCompileSdk" }
                val setCompileSdk = android.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdk" && it.parameterTypes.size == 1
                }
                if (getCompileSdk != null && setCompileSdk != null) {
                    val current = getCompileSdk.invoke(android) as? Int
                    if (current != null && current < 36) {
                        setCompileSdk.invoke(android, 36)
                        logger.lifecycle("A-029 shim: compileSdk $current -> 36 for ${project.name}")
                    }
                }
            }
        }
    }
}
// ---------------------------------------------------------------------------
// Compile-classpath shim for camera_android_camerax — see ADR-030, A-057.
// ---------------------------------------------------------------------------
//
// `camera-core` 1.6.1 annotates `SurfaceRequest.mSurfaceRecreationCompleter`
// with jspecify `@NonNull`, and that annotation references
// `androidx.concurrent.futures.CallbackToFutureAdapter`. javac must be able to
// resolve the referenced type to read the class file at all, so the type is
// needed at COMPILE time — but `camera-core`'s POM declares
// `androidx.concurrent:concurrent-futures` at RUNTIME scope, and Gradle 9.1
// keeps runtime-scoped transitives off the compile classpath. The result:
//
//   :camera_android_camerax:compileDebugJavaWithJavac
//     error: Cannot attach type annotations @org.jspecify.annotations.NonNull
//     to SurfaceRequest.mSurfaceRecreationCompleter:
//     class file for androidx.concurrent.futures.CallbackToFutureAdapter
//     not found
//
// which fails before any application code is compiled.
//
// This is an upstream packaging issue, not a defect in this project, and it is
// not ours to fix at source: `camera_android_camerax` lives in the pub cache,
// is vendored, and any edit there is reverted by the next `flutter pub get`.
//
// It must be applied to THE PLUGIN MODULE, not to `:app`. Gradle module
// classpaths are independent, so declaring the dependency in `app/build.gradle
// .kts` compiles `:app` with it and leaves `:camera_android_camerax` exactly as
// broken — which was tried, and failed with a byte-identical error.
//
// Scoped by name for the same reason the A-029 shim above is: a blanket
// `subprojects` dependency would silently absorb the next plugin with a
// classpath problem instead of failing loudly and forcing a decision.
//
// Remove when camera-core corrects the scope upstream.
val modulesNeedingConcurrentFutures = setOf("camera_android_camerax")

subprojects {
    if (project.name in modulesNeedingConcurrentFutures) {
        afterEvaluate {
            dependencies {
                add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
            }
            logger.lifecycle(
                "camera shim: concurrent-futures -> ${project.name}",
            )
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
