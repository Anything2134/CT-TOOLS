package com.cttools.capture

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs

class FloatingBubbleService : Service() {

    companion object {
        @Volatile
        var isBubbleRunning = false
        private var activeInstance: FloatingBubbleService? = null
        private const val PREFS_NAME = "ct_tools_recorder_cfg"
        private const val KEY_THEME = "current_theme_mode"

        fun refreshBubbleState() {
            activeInstance?.updateVisualState()
        }

        fun updateTheme(context: Context, themeName: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_THEME, themeName)
                .apply()
            activeInstance?.updateVisualState()
        }
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        isBubbleRunning = true
        createFloatingBubble()
        CtToolsWidgetProvider.updateAllWidgets(this)
    }

    private fun createFloatingBubble() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val tv = TextView(this).apply {
            text = if (ScreenRecordService.isRecordingActive) "STOP" else "REC"
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(28, 20, 28, 20)
            elevation = 14f
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 300
        }

        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var moved = false

        tv.setOnTouchListener { _: View, event: MotionEvent ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) {
                        moved = true
                        params.x = initialX + dx
                        params.y = initialY + dy
                        windowManager?.updateViewLayout(tv, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        onBubbleTapped()
                    }
                    true
                }
                else -> false
            }
        }

        bubbleView = tv
        layoutParams = params
        updateVisualState()
        windowManager?.addView(tv, params)
    }

    private fun onBubbleTapped() {
        if (ScreenRecordService.isRecordingActive) {
            val stopIntent = Intent(this, ScreenRecordService::class.java).apply {
                action = ScreenRecordService.ACTION_STOP
            }
            startService(stopIntent)
        } else {
            val promptIntent = Intent(this, ProjectionPromptActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(promptIntent)
        }
    }

    fun updateVisualState() {
        val tv = bubbleView ?: return
        tv.post {
            val recording = ScreenRecordService.isRecordingActive
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val theme = prefs.getString(KEY_THEME, "oledCrimson") ?: "oledCrimson"

            val (borderColor, activeBg, idleBg, textColor) = when (theme) {
                "pureNoir" -> Quad(
                    Color.parseColor("#FFFFFFFF"),
                    Color.parseColor("#FFFFFFFF"),
                    Color.parseColor("#E6000000"),
                    if (recording) Color.BLACK else Color.WHITE
                )
                "mpvInfinite" -> Quad(
                    Color.parseColor("#FF3A3A3C"),
                    Color.parseColor("#CCFF002B"),
                    Color.parseColor("#E6161618"),
                    Color.WHITE
                )
                else -> Quad( // oledCrimson
                    Color.parseColor("#FFFF002B"),
                    Color.parseColor("#CCFF002B"),
                    Color.parseColor("#E6050505"),
                    Color.WHITE
                )
            }

            tv.text = if (recording) "■ STOP" else "● REC"
            tv.setTextColor(textColor)

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 48f
                setColor(if (recording) activeBg else idleBg)
                setStroke(3, borderColor)
            }
            tv.background = bg
        }
    }

    private data class Quad(val border: Int, val active: Int, val idle: Int, val text: Int)

    override fun onDestroy() {
        super.onDestroy()
        isBubbleRunning = false
        activeInstance = null
        bubbleView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {
            }
        }
        bubbleView = null
        CtToolsWidgetProvider.updateAllWidgets(this)
    }
}
