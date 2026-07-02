package com.cube23.balloonburst

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val lifecycleChannelName = "com.cube23.balloonburst/lifecycle"
    private var lifecycleChannel: MethodChannel? = null
    private var sentPaused = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannelName
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        sendNativePause("userLeaveHint")
    }

    override fun onPause() {
        super.onPause()
        sendNativePause("onPause")
    }

    override fun onResume() {
        super.onResume()

        if (sentPaused) {
            sentPaused = false
            lifecycleChannel?.invokeMethod("nativeResume", null)
        }
    }

    private fun sendNativePause(reason: String) {
        if (sentPaused) return

        sentPaused = true
        lifecycleChannel?.invokeMethod("nativePause", reason)
    }
}
