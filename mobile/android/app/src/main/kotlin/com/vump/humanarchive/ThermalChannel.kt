package com.vump.humanarchive

import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the device's current thermal status.
 *
 * Migration 0017 adds `chunk_metadata.thermal_state`, and Volume 5 Chapter 5.7
 * §2 wants capture conditions read "at the moment of chunk finalization". Dart
 * has no thermal API and no admitted package exposes one, so this is the
 * smallest native surface that answers the question.
 *
 * ## Why this is worth a channel at all
 *
 * Mission 8.2 scenario 3 recorded a 25-minute session climbing monotonically
 * through the thermal levels with no throttle event. **That measurement came
 * from `adb`, outside the app, read by a human.** Nothing this application
 * ships could report it, which is half of what open item 152 records. A chunk
 * encoded at status 3 is plausibly different footage from one encoded at 0,
 * and until now the difference was unrecoverable after the fact.
 *
 * ## The value is the platform's own integer, untranslated
 *
 * `PowerManager.getCurrentThermalStatus()` returns 0 (`THERMAL_STATUS_NONE`)
 * through 6 (`THERMAL_STATUS_SHUTDOWN`). It is passed straight through rather
 * than mapped to a name, so there is no translation layer between what the OS
 * reported and what the row says. The column's CHECK constraint documents the
 * range on the storage side.
 *
 * ## Absence is a real answer, not an error
 *
 * The API is 29+, and a device below that — or one whose `PowerManager` is
 * unavailable — returns **null** rather than raising. The column is nullable
 * for exactly this case, and a thrown error would turn "this platform cannot
 * tell us" into a failed chunk finalization, which would be a far worse
 * outcome than an absent field.
 *
 * Note the distinction this preserves: **0 is a reading**, meaning the device
 * is cool. Null means nothing was read. Collapsing the two would erase the
 * difference between a device that reported it was fine and one that reported
 * nothing at all.
 */
object ThermalChannel {
    /** Channel name, mirrored exactly in `thermal_channel.dart`. */
    private const val CHANNEL = "vump/thermal"

    /** Registers the handler against [messenger]. */
    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentThermalStatus" -> result.success(readStatus(context))
                else -> result.notImplemented()
            }
        }
    }

    /** The current status, or null where the platform cannot report one. */
    private fun readStatus(context: Context): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return null
        return try {
            power.currentThermalStatus
        } catch (error: RuntimeException) {
            // Some OEM builds have been observed to throw here rather than
            // report a status. Absent is the honest answer; a crash during
            // chunk finalization would not be.
            null
        }
    }
}
