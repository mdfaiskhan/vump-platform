package com.vump.humanarchive

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The project's two platform channels. Each exists rather than a pub
        // package for the reason its own file records — see FreeSpaceChannel
        // for the argument, which DeviceModelChannel inherits.
        FreeSpaceChannel.register(flutterEngine.dartExecutor.binaryMessenger)
        DeviceModelChannel.register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
