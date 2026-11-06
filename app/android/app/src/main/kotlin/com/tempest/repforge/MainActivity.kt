package com.tempest.repforge

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasCamera" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CAMERA_CHANNEL = "com.tempest.repforge/camera"
    }
}
