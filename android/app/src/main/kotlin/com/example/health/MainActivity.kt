package com.example.health

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "health/background_steps",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundTracking" -> {
                    BackgroundStepService.start(this)
                    result.success(true)
                }

                "stopBackgroundTracking" -> {
                    BackgroundStepService.stop(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
