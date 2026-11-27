package com.cube23.balloonburst

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
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
    private val qaWindowChannelName = "com.cube23.balloonburst/qa_window_frames"
    private var qaWindowChannel: MethodChannel? = null
    private var qaWindowProbe: QaWindowFrameMetrics? = null
    private var lifecycleChannel: MethodChannel? = null
    private var sentPaused = false
    // TJ-45N: QA trace markers only; no per-frame listeners or new scheduling.
    private var qaSlowFrameMarkers = 0
    private val qaMaxSlowFrameMarkers = 32

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

        lifecycleChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceDiagnostics" -> result.success(buildDeviceDiagnostics())
                "getQaFrameClockAnchor" -> result.success(
                    mapOf(
                        // System.nanoTime is the native monotonic-clock anchor.
                        // elapsedRealtimeNanos uses the boot-time clock.
                        "monotonicNs" to System.nanoTime(),
                        "boottimeNs" to SystemClock.elapsedRealtimeNanos()
                    )
                )
                // TJ-45L: only invoked in its dedicated QA APK, nine
                // times at run start and nine times on report export.
                // Passive trace marker; never requests an Android frame.
                "resetQaSlowFrameMarkers" -> {
                    qaSlowFrameMarkers = 0
                    result.success(null)
                }
                "traceQaSlowFrame" -> {
                    val args = call.arguments as? Map<*, *>
                    val frameId = (args?.get("frameId") as? Number)?.toLong() ?: -1L
                    val waitUs = (args?.get("requestToBeginUs") as? Number)?.toLong() ?: -1L
                    if (frameId > 0L && waitUs >= 35714L && qaSlowFrameMarkers < qaMaxSlowFrameMarkers) {
                        qaSlowFrameMarkers++
                        // Arrival-time breadcrumb only. NOT physical presentation or a
                        // hard match to the app SurfaceFlinger frame timeline.
                        android.os.Trace.beginSection("TJ45N_f${frameId}_w${waitUs}")
                        android.os.Trace.endSection()
                    }
                    result.success(null)
                }
                "getQaNativeHandoffClockAnchor" -> {
                    android.os.Trace.beginSection("TJ45L_clock_anchor")
                    try {
                        val monoBefore = System.nanoTime()
                        val boot = SystemClock.elapsedRealtimeNanos()
                        val monoAfter = System.nanoTime()
                        result.success(
                            mapOf(
                                "monoBeforeNs" to monoBefore,
                                "boottimeNs" to boot,
                                "monoAfterNs" to monoAfter
                            )
                        )
                    } finally {
                        android.os.Trace.endSection()
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Registration alone adds no frame listener. Only the QA Dart flag
        // invokes "start" during a measured game session.
        qaWindowChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, qaWindowChannelName
        )
        qaWindowChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val probe = qaWindowProbe ?: QaWindowFrameMetrics(window).also {
                        qaWindowProbe = it
                    }
                    result.success(probe.start())
                }
                "snapshot" -> result.success(
                    qaWindowProbe?.snapshot() ?: "qaAndroidWindowFrameProbe: not-started"
                )
                "stop" -> {
                    qaWindowProbe?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        qaWindowProbe?.stop()
        qaWindowChannel?.setMethodCallHandler(null)
        qaWindowChannel = null
        lifecycleChannel?.setMethodCallHandler(null)
        lifecycleChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
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

    private fun buildDeviceDiagnostics(): Map<String, Any> {
        val bytesPerMb = 1024L * 1024L
        val runtime = Runtime.getRuntime()

        val appHeapUsedMb = (runtime.totalMemory() - runtime.freeMemory()) / bytesPerMb
        val appHeapMaxMb = runtime.maxMemory() / bytesPerMb

        val memInfo = ActivityManager.MemoryInfo()
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        activityManager.getMemoryInfo(memInfo)

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "hardware" to Build.HARDWARE,
            "refreshHz" to currentRefreshRate().toDouble(),
            "appHeapUsedMb" to appHeapUsedMb,
            "appHeapMaxMb" to appHeapMaxMb,
            "systemAvailMb" to (memInfo.availMem / bytesPerMb),
            "systemTotalMb" to (memInfo.totalMem / bytesPerMb),
            "systemThresholdMb" to (memInfo.threshold / bytesPerMb),
            "lowMemory" to memInfo.lowMemory
        )
    }

    @Suppress("DEPRECATION")
    private fun currentRefreshRate(): Float {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display?.refreshRate ?: windowManager.defaultDisplay.refreshRate
            } else {
                windowManager.defaultDisplay.refreshRate
            }
        } catch (_: Throwable) {
            0f
        }
    }

    private fun sendNativeDebug(message: String) {
        lifecycleChannel?.invokeMethod("nativeDebug", message)
    }
}
