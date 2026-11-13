package com.cttools.capture

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.widget.RemoteViews
import com.cttools.ct_tools_ui.MainActivity
import com.cttools.ct_tools_ui.R

class CtToolsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_REC = "com.cttools.capture.WIDGET_TOGGLE_REC"
        const val ACTION_TOGGLE_BUBBLE = "com.cttools.capture.WIDGET_TOGGLE_BUBBLE"

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, CtToolsWidgetProvider::class.java))
            if (ids.isEmpty()) return

            val recording = ScreenRecordService.isRecordingActive
            val bubbleOn = FloatingBubbleService.isBubbleRunning

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.ct_tools_widget)
                views.setTextViewText(
                    R.id.widget_title,
                    if (recording) "CT-TOOLS // RECORDING" else "CT-TOOLS // READY"
                )
                views.setTextViewText(R.id.widget_btn_rec, if (recording) "STOP" else "REC")
                views.setTextViewText(R.id.widget_btn_bubble, if (bubbleOn) "HIDE" else "BUBBLE")

                val recIntent = Intent(context, CtToolsWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_REC
                }
                views.setOnClickPendingIntent(
                    R.id.widget_btn_rec,
                    PendingIntent.getBroadcast(
                        context, 1, recIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val bubbleIntent = Intent(context, CtToolsWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_BUBBLE
                }
                views.setOnClickPendingIntent(
                    R.id.widget_btn_bubble,
                    PendingIntent.getBroadcast(
                        context, 2, bubbleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val openIntent = Intent(context, MainActivity::class.java)
                views.setOnClickPendingIntent(
                    R.id.widget_btn_open,
                    PendingIntent.getActivity(
                        context, 3, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                mgr.updateAppWidget(id, views)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateAllWidgets(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE_REC -> {
                if (ScreenRecordService.isRecordingActive) {
                    context.startService(
                        Intent(context, ScreenRecordService::class.java).apply {
                            action = ScreenRecordService.ACTION_STOP
                        }
                    )
                } else {
                    context.startActivity(
                        Intent(context, ProjectionPromptActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    )
                }
            }
            ACTION_TOGGLE_BUBBLE -> {
                if (FloatingBubbleService.isBubbleRunning) {
                    context.stopService(Intent(context, FloatingBubbleService::class.java))
                } else if (Settings.canDrawOverlays(context)) {
                    context.startService(Intent(context, FloatingBubbleService::class.java))
                } else {
                    context.startActivity(
                        Intent(context, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    )
                }
            }
        }
    }
}
