package com.vump.humanarchive

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The project's only platform channel — see FreeSpaceChannel for why
        // it exists rather than a pub package.
        FreeSpaceChannel.register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
