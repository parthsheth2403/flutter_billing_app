package com.parthsheth.billingapp

import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val feedbackChannel = "billing_app/feedback"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            feedbackChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "beep" -> {
                    playBeep()
                    result.success(null)
                }

                "getDeviceId" -> {
                    result.success(resolveDeviceId())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun playBeep() {
        try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
        } catch (_: Exception) {
            // Ignore feedback failures.
        }
    }

    private fun resolveDeviceId(): String? {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        } catch (_: Exception) {
            null
        }
    }
}
