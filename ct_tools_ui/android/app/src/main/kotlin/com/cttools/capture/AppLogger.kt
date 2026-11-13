package com.cttools.capture

import android.content.Context
import android.os.Build
import android.os.Environment
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object AppLogger {

    private const val TAG = "CT-TOOLS"
    private const val PREFS_NAME = "ct_tools_prefs"
    private const val KEY_LOG_ENABLED = "logging_enabled"
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    @Volatile
    private var internalLogFile: File? = null

    @Volatile
    var isEnabled: Boolean = false
        private set

    fun init(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isEnabled = prefs.getBoolean(KEY_LOG_ENABLED, false)
        if (internalLogFile == null) {
            internalLogFile = File(context.filesDir, "ct_tools.log")
        }
        installCrashHandler(context)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        isEnabled = enabled
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LOG_ENABLED, enabled)
            .apply()
        try {
            NativeMediaJni.setLogEnabled(enabled)
        } catch (_: Throwable) {
        }
    }

    private fun installCrashHandler(context: Context) {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        if (defaultHandler is CtCrashHandler) return
        Thread.setDefaultUncaughtExceptionHandler(CtCrashHandler(context.applicationContext, defaultHandler))
    }

    @Synchronized
    fun log(level: String, source: String, message: String) {
        if (!isEnabled) return

        val timestamp = dateFormat.format(Date())
        val line = "[$timestamp] [$level/$source] $message\n"

        when (level) {
            "ERROR" -> Log.e(TAG, "[$source] $message")
            "WARN" -> Log.w(TAG, "[$source] $message")
            else -> Log.i(TAG, "[$source] $message")
        }

        try {
            internalLogFile?.let { file ->
                if (file.exists() && file.length() > 1024 * 1024) {
                    file.writeText("")
                }
                file.appendText(line)
            }
        } catch (_: Exception) {
        }

        try {
            val hasExternal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Environment.isExternalStorageManager()
            } else {
                false
            }
            if (hasExternal) {
                val extDir = File("/sdcard/Movies/CT-TOOLS")
                if (!extDir.exists()) extDir.mkdirs()
                val extLog = File(extDir, "ct_tools.log")
                if (extLog.exists() && extLog.length() > 1024 * 1024) {
                    extLog.writeText("")
                }
                extLog.appendText(line)
            }
        } catch (_: Exception) {
        }
    }

    fun readLogs(context: Context): String {
        init(context)
        return try {
            val file = internalLogFile
            if (file != null && file.exists()) {
                val content = file.readText()
                if (content.isEmpty()) "Logs are empty (logging is ${if (isEnabled) "ENABLED" else "DISABLED"})." else content
            } else {
                "Logging is ${if (isEnabled) "ENABLED" else "DISABLED"}. No log file yet."
            }
        } catch (e: Exception) {
            "Failed to read logs: ${e.message}"
        }
    }

    fun clearLogs(context: Context) {
        init(context)
        try {
            internalLogFile?.writeText("")
            val extLog = File("/sdcard/Movies/CT-TOOLS/ct_tools.log")
            if (extLog.exists()) extLog.writeText("")
        } catch (_: Exception) {
        }
    }

    private class CtCrashHandler(
        private val context: Context,
        private val previous: Thread.UncaughtExceptionHandler?
    ) : Thread.UncaughtExceptionHandler {
        override fun uncaughtException(thread: Thread, throwable: Throwable) {
            init(context)
            if (isEnabled) {
                val trace = Log.getStackTraceString(throwable)
                log("ERROR", "UNCAUGHT_${thread.name}", trace)
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
