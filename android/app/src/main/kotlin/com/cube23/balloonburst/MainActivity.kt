package com.cube23.balloonburst

import android.app.Activity
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore
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
    private var screenshotObserver: ContentObserver? = null

    private var suppressFocusPauseUntilMs = 0L

    private val focusPauseDelayMs = 250L
    private val screenshotSuppressMs = 2600L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannelName
        )
    }

    override fun onStart() {
        super.onStart()
        registerScreenshotExceptionSources()
    }

    override fun onStop() {
        unregisterScreenshotExceptionSources()
        super.onStop()
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

    private fun registerScreenshotExceptionSources() {
        registerScreenCaptureCallbackIfAvailable()
        registerScreenshotMediaObserver()
    }

    private fun unregisterScreenshotExceptionSources() {
        unregisterScreenCaptureCallbackIfAvailable()
        unregisterScreenshotMediaObserver()
    }

    private fun registerScreenCaptureCallbackIfAvailable() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        if (screenCaptureCallback != null) return

        try {
            val callback = Activity.ScreenCaptureCallback {
                markScreenshotException("screenCaptureCallback")
            }

            screenCaptureCallback = callback
            registerScreenCaptureCallback(screenCaptureExecutor, callback)
        } catch (_: Throwable) {
            screenCaptureCallback = null
        }
    }

    private fun unregisterScreenCaptureCallbackIfAvailable() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return

        val callback = screenCaptureCallback ?: return

        try {
            unregisterScreenCaptureCallback(callback)
        } catch (_: Throwable) {
            // Safety cleanup only.
        } finally {
            screenCaptureCallback = null
        }
    }

    private fun registerScreenshotMediaObserver() {
        if (screenshotObserver != null) return

        try {
            val observer = object : ContentObserver(mainHandler) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)
                    markScreenshotException("mediaStoreImageChange")
                }
            }

            screenshotObserver = observer
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                observer
            )
        } catch (_: Throwable) {
            screenshotObserver = null
        }
    }

    private fun unregisterScreenshotMediaObserver() {
        val observer = screenshotObserver ?: return

        try {
            contentResolver.unregisterContentObserver(observer)
        } catch (_: Throwable) {
            // Safety cleanup only.
        } finally {
            screenshotObserver = null
        }
    }

    private fun markScreenshotException(source: String) {
        suppressFocusPauseUntilMs = SystemClock.uptimeMillis() + screenshotSuppressMs
        cancelFocusPause()
        sendNativeDebug("screenshotException=$source")

        if (sentPaused) {
            sentPaused = false
            lifecycleChannel?.invokeMethod("nativeResumeSilent", null)
        }
    }

    private fun isScreenshotExceptionActive(): Boolean {
        return SystemClock.uptimeMillis() < suppressFocusPauseUntilMs
    }

    private fun scheduleFocusPause() {
        cancelFocusPause()

        val runnable = Runnable {
            if (isScreenshotExceptionActive()) {
                sendNativeDebug("focusPauseSuppressed=screenshot")
                return@Runnable
            }

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
        if (isScreenshotExceptionActive()) {
            sendNativeDebug("nativePauseSuppressed=$reason")
            return
        }

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
