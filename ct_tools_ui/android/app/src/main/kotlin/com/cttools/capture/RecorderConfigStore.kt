package com.cttools.capture

import android.content.Context
import android.content.Intent

object RecorderConfigStore {

    private const val PREFS_NAME = "ct_tools_recorder_cfg"

    fun saveFromMap(context: Context, args: Map<String, Any>) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val edit = prefs.edit()
        edit.putInt("orientationMode", (args["orientationMode"] as? Number)?.toInt() ?: 0) // 0=Auto, 1=Portrait, 2=Landscape
        edit.putBoolean("autoAspectFit", (args["autoAspectFit"] as? Boolean) ?: true)
        edit.putInt("width", (args["width"] as? Number)?.toInt() ?: 0)
        edit.putInt("height", (args["height"] as? Number)?.toInt() ?: 0)
        edit.putInt("fps", (args["fps"] as? Number)?.toInt() ?: 60)
        edit.putInt("bitRate", (args["bitRate"] as? Number)?.toInt() ?: 16000000)
        edit.putInt("bitrateMode", (args["bitrateMode"] as? Number)?.toInt() ?: 1)
        edit.putInt("cqQuality", (args["cqQuality"] as? Number)?.toInt() ?: -1)
        edit.putInt("gopFrames", (args["gopFrames"] as? Number)?.toInt() ?: 120)
        edit.putInt("lowLatency", (args["lowLatency"] as? Number)?.toInt() ?: 0)
        edit.putInt("qpMin", (args["qpMin"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpMax", (args["qpMax"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpIMin", (args["qpIMin"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpIMax", (args["qpIMax"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpPMin", (args["qpPMin"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpPMax", (args["qpPMax"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpBMin", (args["qpBMin"] as? Number)?.toInt() ?: -1)
        edit.putInt("qpBMax", (args["qpBMax"] as? Number)?.toInt() ?: -1)
        edit.putInt("audioSource", (args["audioSource"] as? Number)?.toInt() ?: 1)
        edit.putInt("audioCodecType", (args["audioCodecType"] as? Number)?.toInt() ?: 0)
        edit.putInt("audioSampleRate", (args["audioSampleRate"] as? Number)?.toInt() ?: 48000)
        edit.putInt("audioChannels", (args["audioChannels"] as? Number)?.toInt() ?: 2)
        edit.putInt("audioBitrate", (args["audioBitrate"] as? Number)?.toInt() ?: 128000)
        edit.putInt("opusVbrMode", (args["opusVbrMode"] as? Number)?.toInt() ?: 1)
        edit.putInt("audioComplexity", (args["audioComplexity"] as? Number)?.toInt() ?: 10)
        edit.putFloat("opusFrameMs", (args["opusFrameMs"] as? Number)?.toFloat() ?: 20.0f)
        edit.putInt("flacBitDepth", (args["flacBitDepth"] as? Number)?.toInt() ?: 24)
        edit.putString("wavFmt", args["wavFmt"] as? String ?: "pcm_s16le")
        edit.putString("customAudioArgs", args["customAudioArgs"] as? String ?: "")
        edit.putString("codecName", args["codecName"] as? String ?: "")
        edit.putString("mimeType", args["mimeType"] as? String ?: "video/avc")
        edit.putString("outputDir", args["outputDir"] as? String ?: "/sdcard/Movies/CT-TOOLS")
        edit.putString("containerFormat", args["containerFormat"] as? String ?: "auto")
        edit.apply()
    }

    /**
     * Resolves actual recording dimensions for Floating Bubble / Widget triggers,
     * adapting dynamically to current screen orientation and ASIC hardware limits.
     */
    fun buildServiceIntentFromPrefs(
        context: Context,
        resultCode: Int,
        data: Intent
    ): Intent {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val orientationMode = prefs.getInt("orientationMode", 0)
        val autoFit = prefs.getBoolean("autoAspectFit", true)
        val spec = DisplayHelper.getMaxPhysicalDisplaySpec(context)

        val isLandscape = when (orientationMode) {
            1 -> false
            2 -> true
            else -> spec.isCurrentlyLandscape
        }

        val longSide = maxOf(spec.width, spec.height)
        val shortSide = minOf(spec.width, spec.height)
        val panelW = if (isLandscape) longSide else shortSide
        val panelH = if (isLandscape) shortSide else longSide

        val codecName = prefs.getString("codecName", "") ?: ""
        val mimeType = prefs.getString("mimeType", "video/avc") ?: "video/avc"

        var targetW = prefs.getInt("width", 0)
        var targetH = prefs.getInt("height", 0)

        if (targetW <= 0 || targetH <= 0 || orientationMode == 0 || autoFit) {
            val encoders = CodecInspector.getAvailableVideoEncoders(panelW, panelH)
            val enc = encoders.firstOrNull { it["name"] == codecName && it["mime"] == mimeType }
                ?: encoders.firstOrNull { it["mime"] == mimeType }

            val alignW = ((enc?.get("widthAlignment") as? Int) ?: 2).coerceIn(1, 64)
            val alignH = ((enc?.get("heightAlignment") as? Int) ?: 2).coerceIn(1, 64)
            val asicMaxW = (enc?.get("maxWidth") as? Int) ?: panelW
            val asicMaxH = (enc?.get("maxHeight") as? Int) ?: panelH
            val supportsFull = (enc?.get("supportsPanelPortrait") as? Boolean) ?: false

            if (supportsFull || (panelW <= asicMaxW && panelH <= asicMaxH)) {
                targetW = (panelW / alignW) * alignW
                targetH = (panelH / alignH) * alignH
            } else {
                var scale = 1.0
                if (panelW > asicMaxW) scale = asicMaxW.toDouble() / panelW
                if (panelH * scale > asicMaxH) scale = asicMaxH.toDouble() / panelH
                targetW = ((panelW * scale).toInt() / alignW) * alignW
                targetH = ((panelH * scale).toInt() / alignH) * alignH
            }
        }

        val audioSource = prefs.getInt("audioSource", 1)
        val audioCodecType = prefs.getInt("audioCodecType", 0)
        val containerFmt = prefs.getString("containerFormat", "auto") ?: "auto"
        val ext = when (containerFmt) {
            "mp4" -> "mp4"
            "mkv" -> "mkv"
            else -> if ((audioCodecType == 2 && audioSource > 0) || mimeType == "video/avc") "mkv" else "mp4"
        }
        val dir = (prefs.getString("outputDir", "/sdcard/Movies/CT-TOOLS") ?: "/sdcard/Movies/CT-TOOLS")
            .trimEnd('/')
        val outPath = "$dir/ct_capture_${System.currentTimeMillis()}.$ext"

        return Intent(context, ScreenRecordService::class.java).apply {
            action = ScreenRecordService.ACTION_START
            putExtra("resultCode", resultCode)
            putExtra("data", data)
            putExtra("width", targetW.coerceAtLeast(16))
            putExtra("height", targetH.coerceAtLeast(16))
            putExtra("fps", prefs.getInt("fps", spec.refreshRate.toInt().coerceIn(24, 120)))
            putExtra("bitRate", prefs.getInt("bitRate", 16000000))
            putExtra("bitrateMode", prefs.getInt("bitrateMode", 1))
            putExtra("cqQuality", prefs.getInt("cqQuality", -1))
            putExtra("gopFrames", prefs.getInt("gopFrames", 120))
            putExtra("lowLatency", prefs.getInt("lowLatency", 0))
            putExtra("qpMin", prefs.getInt("qpMin", -1))
            putExtra("qpMax", prefs.getInt("qpMax", -1))
            putExtra("qpIMin", prefs.getInt("qpIMin", -1))
            putExtra("qpIMax", prefs.getInt("qpIMax", -1))
            putExtra("qpPMin", prefs.getInt("qpPMin", -1))
            putExtra("qpPMax", prefs.getInt("qpPMax", -1))
            putExtra("qpBMin", prefs.getInt("qpBMin", -1))
            putExtra("qpBMax", prefs.getInt("qpBMax", -1))
            putExtra("audioSource", audioSource)
            putExtra("audioCodecType", audioCodecType)
            putExtra("audioSampleRate", prefs.getInt("audioSampleRate", 48000))
            putExtra("audioChannels", prefs.getInt("audioChannels", 2))
            putExtra("audioBitrate", prefs.getInt("audioBitrate", 128000))
            putExtra("opusVbrMode", prefs.getInt("opusVbrMode", 1))
            putExtra("audioComplexity", prefs.getInt("audioComplexity", 10))
            putExtra("opusFrameMs", prefs.getFloat("opusFrameMs", 20.0f))
            putExtra("flacBitDepth", prefs.getInt("flacBitDepth", 24))
            putExtra("wavFmt", prefs.getString("wavFmt", "pcm_s16le"))
            putExtra("customAudioArgs", prefs.getString("customAudioArgs", ""))
            putExtra("codecName", codecName)
            putExtra("mimeType", mimeType)
            putExtra("outputPath", outPath)
        }
    }
}
