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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
