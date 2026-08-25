package com.vump.humanarchive

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The project's three platform channels. Each exists rather than a pub
        // package for the reason its own file records — see FreeSpaceChannel
        // for the argument, which the other two inherit.
        FreeSpaceChannel.register(flutterEngine.dartExecutor.binaryMessenger)
        DeviceModelChannel.register(flutterEngine.dartExecutor.binaryMessenger)
        // Takes the context as well: PowerManager is a system service, so it
        // needs one, where the other two answer from a path or from Build.
        ThermalChannel.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
