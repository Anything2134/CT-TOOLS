package com.cttools.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.projection.MediaProjection
import android.os.Build
import android.os.IBinder
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import androidx.core.app.NotificationCompat

data class PhysicalDisplaySpec(
    val width: Int,
    val height: Int,
    val refreshRate: Float,
    val densityDpi: Int
)

object DisplayHelper {

    /**
     * Queries the true maximum physical resolution and refresh rate supported by
     * the device's display panel, ignoring software scaling.
     */
    fun getMaxPhysicalDisplaySpec(context: Context): PhysicalDisplaySpec {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val densityDpi = context.resources.displayMetrics.densityDpi

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.maximumWindowMetrics.bounds
            var maxWidth = bounds.width()
            var maxHeight = bounds.height()
            var maxRefresh = display?.refreshRate ?: 60.0f

            display?.supportedModes?.forEach { mode ->
                if (mode.physicalWidth * mode.physicalHeight >= maxWidth * maxHeight) {
                    maxWidth = mode.physicalWidth
                    maxHeight = mode.physicalHeight
                    if (mode.refreshRate > maxRefresh) {
                        maxRefresh = mode.refreshRate
                    }
                }
            }
            return PhysicalDisplaySpec(maxWidth, maxHeight, maxRefresh, densityDpi)
        } else {
            val size = android.graphics.Point()
            @Suppress("DEPRECATION")
            display?.getRealSize(size)
            return PhysicalDisplaySpec(size.x, size.y, display?.refreshRate ?: 60.0f, densityDpi)
        }
    }
}

class ScreenRecordService : Service() {

    companion object {
        const val CHANNEL_ID = "ct_tools_capture_channel"
        const val NOTIFICATION_ID = 4001
        var activeProjection: MediaProjection? = null
        var activeVirtualDisplay: VirtualDisplay? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureNotificationChannel()
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CT-TOOLS Engine Active")
            .setContentText("Hardware GPU capture pipeline running")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        return START_NOT_STICKY
    }

    /**
     * Binds the MediaProjection stream directly to a zero-copy native Surface
     * backed by Rust AMediaCodec.
     */
    fun attachHardwareSurface(surface: Surface, spec: PhysicalDisplaySpec) {
        activeVirtualDisplay?.release()
        activeVirtualDisplay = activeProjection?.createVirtualDisplay(
            "CT_TOOLS_HW_DISPLAY",
            spec.width,
            spec.height,
            spec.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface,
            null,
            null
        )
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
        activeVirtualDisplay?.release()
        activeVirtualDisplay = null
        activeProjection?.stop()
        activeProjection = null
    }
}
