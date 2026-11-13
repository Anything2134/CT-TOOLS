package com.cttools.capture

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build

class AudioCaptureEngine {

    @Volatile
    private var running = false
    private var workerThread: Thread? = null

    @SuppressLint("MissingPermission")
    fun start(
        audioSource: Int,
        sampleRate: Int,
        channels: Int,
        projection: MediaProjection?
    ) {
        if (audioSource == 0) return

        val channelConfig = if (channels == 1) {
            AudioFormat.CHANNEL_IN_MONO
        } else {
            AudioFormat.CHANNEL_IN_STEREO
        }

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(4096)

        val bufBytes = minBuf * 2
        val chunkShorts = 1024 * channels

        var internalRecord: AudioRecord? = null
        var micRecord: AudioRecord? = null

        if ((audioSource == 1 || audioSource == 3) &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            projection != null
        ) {
            try {
                val pbConfig = AudioPlaybackCaptureConfiguration.Builder(projection)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    .build()

                val format = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .build()

                internalRecord = AudioRecord.Builder()
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(bufBytes)
                    .setAudioPlaybackCaptureConfig(pbConfig)
                    .build()
            } catch (e: Exception) {
                AppLogger.log("WARN", "AudioEngine", "PlaybackCapture init failed: ${e.message}")
            }
        }

        if (audioSource == 2 || audioSource == 3) {
            try {
                micRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    channelConfig,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufBytes
                )
            } catch (e: Exception) {
                AppLogger.log("WARN", "AudioEngine", "Microphone init failed: ${e.message}")
            }
        }

        if (internalRecord == null && micRecord == null) {
            AppLogger.log("WARN", "AudioEngine", "No AudioRecord source could be initialized")
            return
        }

        running = true
        internalRecord?.startRecording()
        micRecord?.startRecording()

        workerThread = Thread {
            val bufA = ShortArray(chunkShorts)
            val bufB = ShortArray(chunkShorts)
            val mixBuf = ShortArray(chunkShorts)

            AppLogger.log("INFO", "AudioEngine", "Capture loop started ($sampleRate Hz, ${channels}ch, src=$audioSource)")

            while (running) {
                val readA = internalRecord?.read(bufA, 0, chunkShorts) ?: 0
                val readB = micRecord?.read(bufB, 0, chunkShorts) ?: 0

                if (readA > 0 && readB > 0) {
                    val count = minOf(readA, readB)
                    for (i in 0 until count) {
                        mixBuf[i] = (bufA[i].toInt() + bufB[i].toInt()).coerceIn(-32768, 32767).toShort()
                    }
                    NativeMediaJni.pushAudioPcm(mixBuf, count / channels)
                } else if (readA > 0) {
                    NativeMediaJni.pushAudioPcm(bufA, readA / channels)
                } else if (readB > 0) {
                    NativeMediaJni.pushAudioPcm(bufB, readB / channels)
                } else {
                    Thread.sleep(5)
                }
            }

            try {
                internalRecord?.stop()
                internalRecord?.release()
            } catch (_: Exception) {
            }
            try {
                micRecord?.stop()
                micRecord?.release()
            } catch (_: Exception) {
            }
            AppLogger.log("INFO", "AudioEngine", "Capture loop terminated")
        }.apply { start() }
    }

    fun stop() {
        running = false
        try {
            workerThread?.join(500)
        } catch (_: Exception) {
        }
        workerThread = null
    }
}
