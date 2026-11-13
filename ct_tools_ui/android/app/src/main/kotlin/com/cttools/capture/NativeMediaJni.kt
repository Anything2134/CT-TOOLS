package com.cttools.capture

import android.view.Surface

object NativeMediaJni {
    init {
        System.loadLibrary("ffmpeg")
        System.loadLibrary("ct_media")
    }

    external fun setLogEnabled(enabled: Boolean)

    external fun setLogPath(logPath: String)

    external fun createEncoderSurface(
        width: Int,
        height: Int,
        fps: Int,
        bitRate: Int,
        bitrateMode: Int,
        cqQuality: Int,
        gopFrames: Int,
        lowLatency: Int,
        qpMin: Int,
        qpMax: Int,
        qpIMin: Int,
        qpIMax: Int,
        qpPMin: Int,
        qpPMax: Int,
        qpBMin: Int,
        qpBMax: Int,
        audioEnabled: Int,
        audioCodecType: Int,
        audioSampleRate: Int,
        audioChannels: Int,
        audioBitrate: Int,
        opusVbrMode: Int,
        audioComplexity: Int,
        opusFrameMs: Float,
        flacBitDepth: Int,
        wavFmt: String,
        customAudioArgs: String,
        codecName: String,
        mimeType: String,
        outputPath: String
    ): Surface?

    external fun pushAudioPcm(pcm: ShortArray, samplesPerChannel: Int): Int

    external fun getLastError(): String

    external fun stopCapture(): Int
}
