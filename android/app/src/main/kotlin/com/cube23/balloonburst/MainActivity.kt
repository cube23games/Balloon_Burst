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
        sendNativeDebug("onUserLeaveHint")
        sendNativePause("userLeaveHint")
    }

    override fun onPause() {
        super.onPause()
        sendNativeDebug("onPause")
        sendNativePause("onPause")
    }

    override fun onResume() {
        super.onResume()
        sendNativeDebug("onResume")

        if (sentPaused) {
            sentPaused = false
            lifecycleChannel?.invokeMethod("nativeResume", null)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)

        // Diagnostic only. Do not pause here yet.
        // This signal catches recents/square, but also catches screenshots
        // on this device, so we need the event order before classifying it.
        sendNativeDebug("windowFocusChanged=$hasFocus")
    }

    private fun sendNativePause(reason: String) {
        if (sentPaused) return

        sentPaused = true
        lifecycleChannel?.invokeMethod("nativePause", reason)
    }

    private fun sendNativeDebug(message: String) {
        lifecycleChannel?.invokeMethod("nativeDebug", message)
    }
}
