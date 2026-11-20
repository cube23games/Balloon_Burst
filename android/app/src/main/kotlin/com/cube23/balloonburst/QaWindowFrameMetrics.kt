package com.cube23.balloonburst

import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.view.FrameMetrics
import android.view.Window
import java.util.Locale

/** QA-only Android HOST WINDOW metrics. Not Flutter SurfaceView presents. */
class QaWindowFrameMetrics(private val window: Window) {
    private val lock = Any()
    private var thread: HandlerThread? = null
    private var listener: Window.OnFrameMetricsAvailableListener? = null
    private var samples = 0L
    private var validDeadlines = 0L
    private var missedDeadlines = 0L
    private var callbackDrops = 0L
    private var worstTotalNs = 0L
    private var worstOverrunNs = 0L
    private var invalidSamples = 0L

    fun start(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        synchronized(lock) {
            if (listener != null) return true
            resetLocked()
            val worker = HandlerThread("tj45f-window-frames",
                Process.THREAD_PRIORITY_BACKGROUND)
            worker.start()
            val callback = Window.OnFrameMetricsAvailableListener { _, frame, dropped ->
                val total = frame.getMetric(FrameMetrics.TOTAL_DURATION)
                val deadline = frame.getMetric(FrameMetrics.DEADLINE)
                synchronized(lock) {
                    callbackDrops += dropped.coerceAtLeast(0).toLong()
                    if (total < 0L) {
                        invalidSamples++
                    } else {
                        samples++
                        if (total > worstTotalNs) worstTotalNs = total
                        if (deadline > 0L) {
                            validDeadlines++
                            if (total >= deadline) missedDeadlines++
                            val over = (total - deadline).coerceAtLeast(0L)
                            if (over > worstOverrunNs) worstOverrunNs = over
                        }
                    }
                }
            }
            return try {
                window.addOnFrameMetricsAvailableListener(callback, Handler(worker.looper))
                listener = callback
                thread = worker
                true
            } catch (_: Throwable) {
                worker.quitSafely()
                false
            }
        }
    }

    fun stop() {
        synchronized(lock) {
            val old = listener
            listener = null
            if (old != null) {
                try {
                    window.removeOnFrameMetricsAvailableListener(old)
                } catch (_: Throwable) {
                    // Never let optional QA instrumentation affect gameplay.
                }
            }
            thread?.quitSafely()
            thread = null
        }
    }

    fun snapshot(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return "qaAndroidWindowFrameProbe: unsupported-sdk"
        }
        synchronized(lock) {
            val lines = arrayListOf(
                "qaAndroidWindowFrameProbe: enabled",
                "qaAndroidWindowFrameScope: hostWindowOnly-notSurfacePresentation",
                "qaAndroidWindowFrameSampleCount: $samples",
                "qaAndroidWindowFrameValidDeadlineCount: $validDeadlines",
                "qaAndroidWindowFrameMissedDeadlineCount: $missedDeadlines",
                "qaAndroidWindowFrameCallbackDropCount: $callbackDrops",
                "qaAndroidWindowFrameInvalidSampleCount: $invalidSamples",
                "qaAndroidWindowFrameWorstTotalMs: ${ms(worstTotalNs)}",
                "qaAndroidWindowFrameWorstOverDeadlineMs: ${ms(worstOverrunNs)}"
            )
            if (samples == 0L) {
                lines.add("qaAndroidWindowFrameNote: no-host-window-frames-observed")
            }
            return lines.joinToString("\n")
        }
    }

    private fun resetLocked() {
        samples = 0L
        validDeadlines = 0L
        missedDeadlines = 0L
        callbackDrops = 0L
        worstTotalNs = 0L
        worstOverrunNs = 0L
        invalidSamples = 0L
    }

    private fun ms(nanos: Long): String =
        String.format(Locale.US, "%.2f", nanos / 1_000_000.0)
}
