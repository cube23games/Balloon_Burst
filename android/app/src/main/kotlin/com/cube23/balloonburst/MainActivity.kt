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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannelName
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        cancelFocusPause()
        sendNativePause("userLeaveHint")
    }

    override fun onPause() {
        super.onPause()
        cancelFocusPause()
        sendNativePause("onPause")
    }

    override fun onResume() {
        super.onResume()
        cancelFocusPause()
        sendNativeResume()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)

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
            sendNativePause("windowFocusLost")
        }

        focusPauseRunnable = runnable
        mainHandler.postDelayed(runnable, 160L)
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
}
