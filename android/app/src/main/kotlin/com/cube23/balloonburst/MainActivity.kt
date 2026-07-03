package com.cube23.balloonburst

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class MainActivity : FlutterActivity() {
    private val lifecycleChannelName = "com.cube23.balloonburst/lifecycle"
    private var lifecycleChannel: MethodChannel? = null
    private var sentPaused = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private val screenCaptureExecutor = Executor { command ->
        mainHandler.post(command)
    }

    private var focusPauseRunnable: Runnable? = null
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null
    private var suppressFocusPauseUntilMs = 0L

    private val focusPauseDelayMs = 350L
    private val screenshotSuppressMs = 2200L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannelName
        )
    }

    override fun onStart() {
        super.onStart()
        registerScreenCaptureDetection()
    }

    override fun onStop() {
        unregisterScreenCaptureDetection()
        super.onStop()
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

    private fun registerScreenCaptureDetection() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        if (screenCaptureCallback != null) return

        try {
            val callback = Activity.ScreenCaptureCallback {
                suppressFocusPauseForScreenshot()
            }

            screenCaptureCallback = callback
            registerScreenCaptureCallback(screenCaptureExecutor, callback)
        } catch (_: Throwable) {
            screenCaptureCallback = null
        }
    }

    private fun unregisterScreenCaptureDetection() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return

        val callback = screenCaptureCallback ?: return

        try {
            unregisterScreenCaptureCallback(callback)
        } catch (_: Throwable) {
            // Ignore; this is a safety cleanup path.
        } finally {
            screenCaptureCallback = null
        }
    }

    private fun suppressFocusPauseForScreenshot() {
        suppressFocusPauseUntilMs = SystemClock.uptimeMillis() + screenshotSuppressMs
        cancelFocusPause()

        if (sentPaused) {
            sentPaused = false
            lifecycleChannel?.invokeMethod("nativeResume", null)
        }
    }

    private fun isFocusPauseSuppressed(): Boolean {
        return SystemClock.uptimeMillis() < suppressFocusPauseUntilMs
    }

    private fun scheduleFocusPause() {
        cancelFocusPause()

        val runnable = Runnable {
            if (isFocusPauseSuppressed()) return@Runnable
            sendNativePause("windowFocusLost")
        }

        focusPauseRunnable = runnable
        mainHandler.postDelayed(runnable, focusPauseDelayMs)
    }

    private fun cancelFocusPause() {
        focusPauseRunnable?.let { mainHandler.removeCallbacks(it) }
        focusPauseRunnable = null
    }

    private fun sendNativePause(reason: String) {
        if (isFocusPauseSuppressed()) return
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
