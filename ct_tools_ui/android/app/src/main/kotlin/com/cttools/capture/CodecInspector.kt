package com.cttools.capture

import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build

object CodecInspector {

    private val targetMimes = setOf("video/avc", "video/hevc", "video/av01")

    fun getAvailableVideoEncoders(panelWidth: Int, panelHeight: Int): List<Map<String, Any>> {
        val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val result = mutableListOf<Map<String, Any>>()

        for (info in list.codecInfos) {
            if (!info.isEncoder) continue

            val isHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                info.isHardwareAccelerated
            } else {
                !info.name.startsWith("OMX.google.") && !info.name.startsWith("c2.android.")
            }

            for (mime in info.supportedTypes) {
                val lowerMime = mime.lowercase()
                if (!targetMimes.contains(lowerMime)) continue

                try {
                    val caps = info.getCapabilitiesForType(mime)
                    val videoCaps = caps.videoCapabilities ?: continue
                    val encoderCaps = caps.encoderCapabilities

                    val supportedModes = mutableListOf<Int>()
                    if (encoderCaps != null) {
                        if (encoderCaps.isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CQ)) {
                            supportedModes.add(0)
                        }
                        if (encoderCaps.isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)) {
                            supportedModes.add(1)
                        }
                        if (encoderCaps.isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)) {
                            supportedModes.add(2)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            encoderCaps.isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR_FD)
                        ) {
                            supportedModes.add(3)
                        }
                    }

                    val qualityRange = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && encoderCaps != null) {
                        encoderCaps.qualityRange
                    } else {
                        null
                    }

                    val alignW = videoCaps.widthAlignment.coerceAtLeast(1)
                    val alignH = videoCaps.heightAlignment.coerceAtLeast(1)
                    val alignedPanelW = (panelWidth / alignW) * alignW
                    val alignedPanelH = (panelHeight / alignH) * alignH
                    val supportsPanelPortrait = videoCaps.isSizeSupported(alignedPanelW, alignedPanelH)

                    result.add(
                        mapOf(
                            "name" to info.name,
                            "mime" to lowerMime,
                            "isHardware" to isHardware,
                            "minWidth" to videoCaps.supportedWidths.lower,
                            "maxWidth" to videoCaps.supportedWidths.upper,
                            "minHeight" to videoCaps.supportedHeights.lower,
                            "maxHeight" to videoCaps.supportedHeights.upper,
                            "widthAlignment" to alignW,
                            "heightAlignment" to alignH,
                            "supportsPanelPortrait" to supportsPanelPortrait,
                            "maxFps" to videoCaps.supportedFrameRates.upper,
                            "supportedBitrateModes" to supportedModes,
                            "qualityMin" to (qualityRange?.lower ?: 0),
                            "qualityMax" to (qualityRange?.upper ?: 100)
                        )
                    )
                } catch (_: Exception) {
                }
            }
        }

        return result.sortedByDescending { it["isHardware"] as Boolean }
    }
}
