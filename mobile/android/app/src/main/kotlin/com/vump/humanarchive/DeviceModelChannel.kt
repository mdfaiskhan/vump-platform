package com.vump.humanarchive

import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the OS device model for Volume 4 Chapter 4.4 §7's `device_model`.
 *
 * ## Why a channel and not a pub package
 *
 * Same reasoning `FreeSpaceChannel` records, applied to a smaller question.
 * `device_info_plus` surfaces dozens of fields across both platforms and would
 * carry ADR-030's full admission — confinement entry, inventory row,
 * conversion boundary — to read two constants that Android hands over for
 * free. Mission 7.4, F22.
 *
 * ## `MANUFACTURER MODEL`, not `MODEL` alone
 *
 * `Build.MODEL` on the project's test device is `CPH2707`, which identifies
 * nothing to a human reading A-08's metadata screen. Prefixed with
 * `Build.MANUFACTURER` it reads `OnePlus CPH2707`, which does.
 *
 * The manufacturer is dropped when the model already begins with it, so a
 * device reporting `Samsung Galaxy S21` does not become `samsung Samsung
 * Galaxy S21`. Vendors are inconsistent about this and the duplication is
 * common enough to be worth one comparison.
 *
 * ## Scope
 *
 * One method, no state, no lifecycle, no permissions. `Build` is a set of
 * compile-time constants on the device image — there is nothing to fail, which
 * is why the Dart side treats absence rather than errors as the failure mode.
 */
object DeviceModelChannel {

    private const val CHANNEL = "vump/device_model"

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceModel" -> result.success(describe())
                else -> result.notImplemented()
            }
        }
    }

    /** `manufacturer model`, de-duplicated, trimmed. */
    private fun describe(): String {
        val manufacturer = Build.MANUFACTURER.orEmpty().trim()
        val model = Build.MODEL.orEmpty().trim()

        return when {
            model.isEmpty() -> manufacturer
            manufacturer.isEmpty() -> model
            model.startsWith(manufacturer, ignoreCase = true) -> model
            else -> "$manufacturer $model"
        }
    }
}
