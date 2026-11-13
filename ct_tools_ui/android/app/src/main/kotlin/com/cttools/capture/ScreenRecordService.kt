package com.cttools.capture

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.File

data class PhysicalDisplaySpec(
    val width: Int,
    val height: Int,
    val refreshRate: Float,
    val densityDpi: Int,
    val isCurrentlyLandscape: Boolean
)

object DisplayHelper {

    fun getMaxPhysicalDisplaySpec(context: Context): PhysicalDisplaySpec {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val densityDpi = context.resources.displayMetrics.densityDpi

        val isLandscape = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() > bounds.height()
        } else {
            context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        }

        var rawW = 1080
        var rawH = 1920
        var maxRefresh = display?.refreshRate ?: 60.0f

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.maximumWindowMetrics.bounds
            rawW = bounds.width()
            rawH = bounds.height()
            display?.supportedModes?.forEach { mode ->
                if (mode.physicalWidth * mode.physicalHeight >= rawW * rawH) {
                    rawW = mode.physicalWidth
                    rawH = mode.physicalHeight
                    if (mode.refreshRate > maxRefresh) {
                        maxRefresh = mode.refreshRate
                    }
                }
            }
        } else {
            val size = android.graphics.Point()
            @Suppress("DEPRECATION")
            display?.getRealSize(size)
            rawW = size.x
            rawH = size.y
        }

        val longSide = maxOf(rawW, rawH)
        val shortSide = minOf(rawW, rawH)
        val finalW = if (isLandscape) longSide else shortSide
        val finalH = if (isLandscape) shortSide else longSide

        return PhysicalDisplaySpec(finalW, finalH, maxRefresh, densityDpi, isLandscape)
    }
}

class ScreenRecordService : Service() {

    companion object {
        const val CHANNEL_ID = "ct_tools_capture_channel"
        const val NOTIFICATION_ID = 4001
        const val ACTION_START = "com.cttools.capture.START"
        const val ACTION_STOP = "com.cttools.capture.STOP"

        @Volatile
        var isRecordingActive: Boolean = false
        var activeProjection: MediaProjection? = null
        var activeVirtualDisplay: VirtualDisplay? = null
        var activeSurface: Surface? = null
        var activeAudioEngine: AudioCaptureEngine? = null
        var lastServiceError: String = ""
    }

    private var isStopping = false
    private var wakeLock: PowerManager.WakeLock? = null

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            AppLogger.log("INFO", "Service", "MediaProjection.Callback.onStop triggered by system")
            stopRecordingInternal()
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        AppLogger.init(this)
        AppLogger.log("INFO", "Service", "ScreenRecordService created")
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) return
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CTTOOLS::HardwareCaptureWakeLock").apply {
                setReferenceCounted(false)
                acquire(12 * 60 * 60 * 1000L) // Up to 12h safety timeout
            }
            AppLogger.log("INFO", "Service", "PARTIAL_WAKE_LOCK acquired")
        } catch (e: Exception) {
            AppLogger.log("WARN", "Service", "WakeLock acquire failed: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                AppLogger.log("INFO", "Service", "PARTIAL_WAKE_LOCK released")
            }
            wakeLock = null
        } catch (_: Exception) {
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AppLogger.init(this)

        if (intent?.action == ACTION_STOP) {
            AppLogger.log("INFO", "Service", "Received ACTION_STOP")
            stopRecordingInternal()
            stopSelf()
            return START_NOT_STICKY
        }

        ensureNotificationChannel()
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CT-TOOLS Engine Active")
            .setContentText("Hardware GPU + FFmpeg Audio pipeline running (WakeLock active)")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        if (intent?.action == ACTION_START) {
            lastServiceError = ""
            isStopping = false
            acquireWakeLock()

            try {
                val resultCode = intent.getIntExtra("resultCode", Activity.RESULT_CANCELED)
                val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra("data", Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra("data")
                }

                if (resultCode != Activity.RESULT_OK || data == null) {
                    lastServiceError = "Invalid MediaProjection result code or null data"
                    AppLogger.log("ERROR", "Service", lastServiceError)
                    stopRecordingInternal()
                    stopSelf()
                    return START_NOT_STICKY
                }

                val projectionManager =
                    getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val projection = projectionManager.getMediaProjection(resultCode, data)
                if (projection == null) {
                    lastServiceError = "getMediaProjection returned null"
                    AppLogger.log("ERROR", "Service", lastServiceError)
                    stopRecordingInternal()
                    stopSelf()
                    return START_NOT_STICKY
                }

                projection.registerCallback(projectionCallback, Handler(Looper.getMainLooper()))
                activeProjection = projection

                NativeMediaJni.setLogEnabled(AppLogger.isEnabled)
                NativeMediaJni.setLogPath(File(filesDir, "ct_tools.log").absolutePath)

                val width = intent.getIntExtra("width", 1080)
                val height = intent.getIntExtra("height", 1920)
                val fps = intent.getIntExtra("fps", 60)
                val bitRate = intent.getIntExtra("bitRate", 12000000)
                val bitrateMode = intent.getIntExtra("bitrateMode", 1)
                val cqQuality = intent.getIntExtra("cqQuality", -1)
                val gopFrames = intent.getIntExtra("gopFrames", 120)
                val lowLatency = intent.getIntExtra("lowLatency", 0)

                val qpMin = intent.getIntExtra("qpMin", -1)
                val qpMax = intent.getIntExtra("qpMax", -1)
                val qpIMin = intent.getIntExtra("qpIMin", -1)
                val qpIMax = intent.getIntExtra("qpIMax", -1)
                val qpPMin = intent.getIntExtra("qpPMin", -1)
                val qpPMax = intent.getIntExtra("qpPMax", -1)
                val qpBMin = intent.getIntExtra("qpBMin", -1)
                val qpBMax = intent.getIntExtra("qpBMax", -1)

                val audioSource = intent.getIntExtra("audioSource", 1)
                val audioCodecType = intent.getIntExtra("audioCodecType", 0)
                val audioSampleRate = intent.getIntExtra("audioSampleRate", 48000)
                val audioChannels = intent.getIntExtra("audioChannels", 2)
                val audioBitrate = intent.getIntExtra("audioBitrate", 128000)
                val opusVbrMode = intent.getIntExtra("opusVbrMode", 1)
                val audioComplexity = intent.getIntExtra("audioComplexity", 10)
                val opusFrameMs = intent.getFloatExtra("opusFrameMs", 20.0f)
                val flacBitDepth = intent.getIntExtra("flacBitDepth", 24)
                val wavFmt = intent.getStringExtra("wavFmt") ?: "pcm_s16le"
                val customAudioArgs = intent.getStringExtra("customAudioArgs") ?: ""

                val codecName = intent.getStringExtra("codecName") ?: ""
                val mimeType = intent.getStringExtra("mimeType") ?: "video/avc"
                val outputPath = intent.getStringExtra("outputPath")
                    ?: "/sdcard/Movies/CT-TOOLS/ct_capture.mkv"
                val densityDpi = resources.displayMetrics.densityDpi

                val surface = NativeMediaJni.createEncoderSurface(
                    width, height, fps, bitRate, bitrateMode, cqQuality, gopFrames, lowLatency,
                    qpMin, qpMax, qpIMin, qpIMax, qpPMin, qpPMax, qpBMin, qpBMax,
                    if (audioSource > 0) 1 else 0,
                    audioCodecType, audioSampleRate, audioChannels, audioBitrate,
                    opusVbrMode, audioComplexity, opusFrameMs, flacBitDepth,
                    wavFmt, customAudioArgs, codecName, mimeType, outputPath
                )

                if (surface != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            surface.setFrameRate(
                                fps.toFloat(),
                                Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE
                            )
                        } catch (_: Exception) {
                        }
                    }

                    activeSurface = surface
                    activeVirtualDisplay = projection.createVirtualDisplay(
                        "CT_TOOLS_HW_DISPLAY",
                        width,
                        height,
                        densityDpi,
                        DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                        surface,
                        null,
                        null
                    )

                    if (audioSource > 0) {
                        val engine = AudioCaptureEngine()
                        engine.start(audioSource, audioSampleRate, audioChannels, projection)
                        activeAudioEngine = engine
                    }

                    isRecordingActive = true
                    FloatingBubbleService.refreshBubbleState()
                    CtToolsWidgetProvider.updateAllWidgets(this)
                    AppLogger.log("INFO", "Service", "Capture active (${width}x$height, audioSrc=$audioSource) -> $outputPath")
                } else {
                    lastServiceError = NativeMediaJni.getLastError().ifEmpty {
                        "createEncoderSurface returned null"
                    }
                    AppLogger.log("ERROR", "Service", lastServiceError)
                    stopRecordingInternal()
                    stopSelf()
                }
            } catch (t: Throwable) {
                lastServiceError = "Service exception: ${t.message}"
                AppLogger.log("ERROR", "Service", Log.getStackTraceString(t))
                stopRecordingInternal()
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    @Synchronized
    private fun stopRecordingInternal() {
        if (isStopping) return
        isStopping = true
        isRecordingActive = false

        try {
            activeAudioEngine?.stop()
            activeAudioEngine = null
        } catch (_: Exception) {
        }

        try {
            activeVirtualDisplay?.release()
            activeVirtualDisplay = null
        } catch (_: Exception) {
        }

        try {
            NativeMediaJni.stopCapture()
        } catch (_: Exception) {
        }

        try {
            activeSurface?.release()
            activeSurface = null
        } catch (_: Exception) {
        }

        try {
            activeProjection?.unregisterCallback(projectionCallback)
            activeProjection?.stop()
            activeProjection = null
        } catch (_: Exception) {
        }

        releaseWakeLock()
        FloatingBubbleService.refreshBubbleState()
        CtToolsWidgetProvider.updateAllWidgets(this)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CT-TOOLS Hardware Capture",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRecordingInternal()
    }
}
