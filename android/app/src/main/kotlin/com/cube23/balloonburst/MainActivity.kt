package com.cube23.balloonburst

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val lifecycleChannelName = "com.cube23.balloonburst/lifecycle"
    private var lifecycleChannel: MethodChannel? = null
    private var sentPaused = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var focusPauseRunnable: Runnable? = null

    // Sustained focus loss only.
    // Short focus-loss blips happen during screenshots, so do not pause instantly.
    private val focusPauseDelayMs = 900L

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
        cancelFocusPause()
        sendNativePause("userLeaveHint")
    }

    override fun onPause() {
        super.onPause()
        sendNativeDebug("onPause")
        cancelFocusPause()
        sendNativePause("onPause")
    }

    override fun onResume() {
        super.onResume()
        sendNativeDebug("onResume")
        cancelFocusPause()
        sendNativeResume()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)

        sendNativeDebug("windowFocusChanged=$hasFocus")

        if (hasFocus) {
            cancelFocusPause()
            sendNativeResume()
            return
        }

        scheduleFocusPause()
    }

    private fun scheduleFocusPause() {
        cancelFocusPause()

        val runnable = Runnable {
            sendNativePause("windowFocusLostSustained")
        }

        focusPauseRunnable = runnable
        mainHandler.postDelayed(runnable, focusPauseDelayMs)
    }

    private fun cancelFocusPause() {
        focusPauseRunnable?.let { mainHandler.removeCallbacks(it) }
        focusPauseRunnable = null
    }

    private fun sendNativePause(reason: String) {
        if (sentPaused) return

        sentPaused = true
        lifecycleChannel?.invokeMethod("nativePause", reason)
    }

    private fun sendNativeResume() {
        if (!sentPaused) return

        sentPaused = false
        lifecycleChannel?.invokeMethod("nativeResume", null)
    }

    private fun sendNativeDebug(message: String) {
        lifecycleChannel?.invokeMethod("nativeDebug", message)
    }
}
