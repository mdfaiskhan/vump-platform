package com.vump.humanarchive

import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reports free bytes on the volume holding a given path.
 *
 * Volume 5 Chapter 5.4 §2 requires the pipeline to watch remaining free space
 * while recording and force an early chunk boundary before a write can fail.
 * Dart has no such API — `dart:io` exposes no free-space call at all — so this
 * is the smallest native surface that answers the question.
 *
 * ## Why a channel and not a pub package
 *
 * The two maintained candidates both return **megabytes as a float**. This
 * project shipped a defect (see amendment A-057's correction) caused by
 * trusting a 32-bit float that crossed this exact boundary, so a measurement
 * path that discards byte precision by construction was rejected. This returns
 * `Long` bytes and the Dart side reads `int`. No floating point anywhere.
 *
 * A package would also carry ADR-030's full admission — confinement entry,
 * inventory row, conversion boundary — for roughly twenty lines of platform
 * code.
 *
 * ## Scope
 *
 * One method, no state, no lifecycle. It measures the volume containing
 * [path], which the caller supplies as the directory it actually writes
 * chunks to — never a guessed partition, which is what
 * `Environment.getDataDirectory()` would be.
 */
object FreeSpaceChannel {
    /** Channel name, mirrored exactly in `free_space_channel.dart`. */
    private const val CHANNEL = "vump/free_space"

    /** Registers the handler against [messenger]. */
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "availableBytes" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error(
                            "INVALID_PATH",
                            "availableBytes requires a non-empty 'path'.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        // availableBytes is API 18+; this app's minSdk is well
                        // above that, so no legacy blockSize path is needed.
                        // It reports bytes available to *this* application,
                        // which is the number that decides whether the next
                        // write succeeds — not the raw free space, which can
                        // include reserved blocks the app cannot use.
                        result.success(StatFs(path).availableBytes)
                    } catch (error: IllegalArgumentException) {
                        result.error(
                            "STAT_FAILED",
                            "Could not stat the volume for the given path.",
                            error.toString(),
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
