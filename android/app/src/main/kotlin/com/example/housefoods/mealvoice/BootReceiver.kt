package com.example.housefoods.mealvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Handles multiple events:
 * 1. BOOT_COMPLETED — auto-start voice service on device boot
 * 2. SERVICE_RESTART — periodic alarm to keep voice service alive
 * 3. MY_PACKAGE_REPLACED — restart service after app update
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MEAL_BootReceiver"
        private const val PREFS_NAME = "meal_voice_prefs"
        private const val KEY_ENABLED = "voice_enabled"
        const val ACTION_SERVICE_RESTART = "com.mealin.SERVICE_RESTART"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "Received action: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            ACTION_SERVICE_RESTART,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                checkAndStartService(context)
            }
        }
    }

    private fun checkAndStartService(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasEnabled = prefs.getBoolean(KEY_ENABLED, false)

        if (wasEnabled) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+ prohibits starting a microphone foreground service
                // from BOOT_COMPLETED because microphone permission is while-in-use.
                // The user must open the app and explicitly restart MEAL.
                Log.w(TAG, "Android 14+: not starting microphone service from boot")
                return
            }
            Log.i(TAG, "Voice service was enabled — starting")
            val serviceIntent = Intent(context, MealVoiceService::class.java).apply {
                action = "ACTION_RESTART_ENGINE"
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service", e)
            }
        } else {
            Log.i(TAG, "Voice service was not enabled — skipping")
        }
    }
}
