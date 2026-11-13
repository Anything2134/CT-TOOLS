package com.cttools.capture

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class ProjectionPromptActivity : Activity() {

    private val reqMediaProjection = 9101
    private val reqAudio = 9102

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppLogger.init(this)

        val prefs = getSharedPreferences("ct_tools_recorder_cfg", Context.MODE_PRIVATE)
        val audioSrc = prefs.getInt("audioSource", 1)

        if (audioSrc > 0 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), reqAudio)
        } else {
            promptProjection()
        }
    }

    private fun promptProjection() {
        val pm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(pm.createScreenCaptureIntent(), reqMediaProjection)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == reqAudio) {
            promptProjection()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqMediaProjection && resultCode == RESULT_OK && data != null) {
            val serviceIntent = RecorderConfigStore.buildServiceIntentFromPrefs(this, resultCode, data)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
        finish()
    }
}
