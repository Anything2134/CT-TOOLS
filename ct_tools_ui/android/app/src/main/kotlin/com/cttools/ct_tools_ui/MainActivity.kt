package com.cttools.ct_tools_ui

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.cttools.capture.AppLogger
import com.cttools.capture.CodecInspector
import com.cttools.capture.DisplayHelper
import com.cttools.capture.FloatingBubbleService
import com.cttools.capture.NativeMediaJni
import com.cttools.capture.RecorderConfigStore
import com.cttools.capture.ScreenRecordService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.cttools/platform"
    private val mediaProjectionRequestCode = 9001
    private val recordAudioRequestCode = 9002

    private var pendingStartArgs: Map<String, Any>? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        AppLogger.init(this)
        super.onCreate(savedInstanceState)
    }

    @SuppressLint("BatteryLife")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppLogger.init(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMaxDisplaySpec" -> {
                        val spec = DisplayHelper.getMaxPhysicalDisplaySpec(this)
                        result.success(
                            mapOf(
                                "width" to spec.width,
                                "height" to spec.height,
                                "refreshRate" to spec.refreshRate.toDouble(),
                                "densityDpi" to spec.densityDpi,
                                "isLandscape" to spec.isCurrentlyLandscape
                            )
                        )
                    }
                    "getVideoEncoders" -> {
                        val spec = DisplayHelper.getMaxPhysicalDisplaySpec(this)
                        result.success(CodecInspector.getAvailableVideoEncoders(spec.width, spec.height))
                    }
                    "getStorageDir" -> result.success(filesDir.absolutePath)
                    "isRecordingActive" -> result.success(ScreenRecordService.isRecordingActive)
                    "hasAllFilesPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else true
                        result.success(granted)
                    }
                    "requestAllFilesPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                            } catch (_: Exception) {
                                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                            }
                        }
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        } catch (_: Exception) {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        }
                        result.success(true)
                    }
                    "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }
                    "isFloatingBubbleActive" -> result.success(FloatingBubbleService.isBubbleRunning)
                    "setBubbleTheme" -> {
                        val theme = call.argument<String>("theme") ?: "oledCrimson"
                        FloatingBubbleService.updateTheme(this, theme)
                        result.success(true)
                    }
                    "toggleFloatingBubble" -> {
                        @Suppress("UNCHECKED_CAST")
                        (call.arguments as? Map<String, Any>)?.let {
                            RecorderConfigStore.saveFromMap(this, it)
                        }
                        if (FloatingBubbleService.isBubbleRunning) {
                            stopService(Intent(this, FloatingBubbleService::class.java))
                            result.success(false)
                        } else if (Settings.canDrawOverlays(this)) {
                            startService(Intent(this, FloatingBubbleService::class.java))
                            result.success(true)
                        } else {
                            result.error("NO_OVERLAY_PERMISSION", "Overlay permission required", null)
                        }
                    }
                    "saveRecorderConfig" -> {
                        @Suppress("UNCHECKED_CAST")
                        (call.arguments as? Map<String, Any>)?.let {
                            RecorderConfigStore.saveFromMap(this, it)
                        }
                        result.success(true)
                    }
                    "getLastCaptureError" -> {
                        val err = ScreenRecordService.lastServiceError.ifEmpty {
                            NativeMediaJni.getLastError()
                        }
                        result.success(err)
                    }
                    "isLoggingEnabled" -> result.success(AppLogger.isEnabled)
                    "setLoggingEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        AppLogger.setEnabled(this, enabled)
                        result.success(true)
                    }
                    "readLogs" -> result.success(AppLogger.readLogs(this))
                    "clearLogs" -> {
                        AppLogger.clearLogs(this)
                        result.success(true)
                    }
                    "appendLog" -> {
                        val level = call.argument<String>("level") ?: "INFO"
                        val source = call.argument<String>("source") ?: "Flutter"
                        val msg = call.argument<String>("message") ?: ""
                        AppLogger.log(level, source, msg)
                        result.success(true)
                    }
                    "startScreenCapture" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any> ?: emptyMap()
                        RecorderConfigStore.saveFromMap(this, args)
                        pendingStartArgs = args
                        pendingResult = result
                        val audioSrc = (args["audioSource"] as? Number)?.toInt() ?: 0
                        if (audioSrc > 0 &&
                            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                recordAudioRequestCode
                            )
                        } else {
                            launchMediaProjectionPrompt()
                        }
                    }
                    "stopScreenCapture" -> {
                        val stopIntent = Intent(this, ScreenRecordService::class.java).apply {
                            action = ScreenRecordService.ACTION_STOP
                        }
                        startService(stopIntent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchMediaProjectionPrompt() {
        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            mediaProjectionRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == recordAudioRequestCode) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                launchMediaProjectionPrompt()
            } else {
                AppLogger.log("WARN", "MainActivity", "RECORD_AUDIO denied; falling back to video-only")
                pendingStartArgs = pendingStartArgs?.toMutableMap()?.apply { put("audioSource", 0) }
                launchMediaProjectionPrompt()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == mediaProjectionRequestCode) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val args = pendingStartArgs ?: emptyMap()
                val serviceIntent = Intent(this, ScreenRecordService::class.java).apply {
                    action = ScreenRecordService.ACTION_START
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("width", (args["width"] as? Number)?.toInt() ?: 1080)
                    putExtra("height", (args["height"] as? Number)?.toInt() ?: 1920)
                    putExtra("fps", (args["fps"] as? Number)?.toInt() ?: 60)
                    putExtra("bitRate", (args["bitRate"] as? Number)?.toInt() ?: 12000000)
                    putExtra("bitrateMode", (args["bitrateMode"] as? Number)?.toInt() ?: 1)
                    putExtra("cqQuality", (args["cqQuality"] as? Number)?.toInt() ?: -1)
                    putExtra("gopFrames", (args["gopFrames"] as? Number)?.toInt() ?: 120)
                    putExtra("lowLatency", (args["lowLatency"] as? Number)?.toInt() ?: 0)
                    putExtra("qpMin", (args["qpMin"] as? Number)?.toInt() ?: -1)
                    putExtra("qpMax", (args["qpMax"] as? Number)?.toInt() ?: -1)
                    putExtra("qpIMin", (args["qpIMin"] as? Number)?.toInt() ?: -1)
                    putExtra("qpIMax", (args["qpIMax"] as? Number)?.toInt() ?: -1)
                    putExtra("qpPMin", (args["qpPMin"] as? Number)?.toInt() ?: -1)
                    putExtra("qpPMax", (args["qpPMax"] as? Number)?.toInt() ?: -1)
                    putExtra("qpBMin", (args["qpBMin"] as? Number)?.toInt() ?: -1)
                    putExtra("qpBMax", (args["qpBMax"] as? Number)?.toInt() ?: -1)
                    putExtra("audioSource", (args["audioSource"] as? Number)?.toInt() ?: 1)
                    putExtra("audioCodecType", (args["audioCodecType"] as? Number)?.toInt() ?: 0)
                    putExtra("audioSampleRate", (args["audioSampleRate"] as? Number)?.toInt() ?: 48000)
                    putExtra("audioChannels", (args["audioChannels"] as? Number)?.toInt() ?: 2)
                    putExtra("audioBitrate", (args["audioBitrate"] as? Number)?.toInt() ?: 128000)
                    putExtra("opusVbrMode", (args["opusVbrMode"] as? Number)?.toInt() ?: 1)
                    putExtra("audioComplexity", (args["audioComplexity"] as? Number)?.toInt() ?: 10)
                    putExtra("opusFrameMs", (args["opusFrameMs"] as? Number)?.toFloat() ?: 20.0f)
                    putExtra("flacBitDepth", (args["flacBitDepth"] as? Number)?.toInt() ?: 24)
                    putExtra("wavFmt", args["wavFmt"] as? String ?: "pcm_s16le")
                    putExtra("customAudioArgs", args["customAudioArgs"] as? String ?: "")
                    putExtra("codecName", args["codecName"] as? String ?: "")
                    putExtra("mimeType", args["mimeType"] as? String ?: "video/avc")
                    putExtra("outputPath", args["outputPath"] as? String ?: "/sdcard/Movies/CT-TOOLS/ct_capture.mkv")
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                pendingResult?.success(true)
            } else {
                AppLogger.log("WARN", "MainActivity", "MediaProjection permission denied by user")
                pendingResult?.error("PERMISSION_DENIED", "MediaProjection permission denied", null)
            }
            pendingStartArgs = null
            pendingResult = null
        }
    }
}
