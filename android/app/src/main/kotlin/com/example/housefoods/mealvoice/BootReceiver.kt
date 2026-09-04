package com.example.housefoods.mealvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * Auto-starts MealVoiceService on device boot if the user previously enabled it.
 * Uses SharedPreferences to remember the user's preference.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MEAL_BootReceiver"
        private const val PREFS_NAME = "meal_voice_prefs"
        private const val KEY_ENABLED = "voice_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.i(TAG, "Boot completed — checking if voice service should start")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasEnabled = prefs.getBoolean(KEY_ENABLED, false)

        if (wasEnabled) {
            Log.i(TAG, "Voice service was enabled — starting on boot")
            val serviceIntent = Intent(context, MealVoiceService::class.java).apply {
                action = "ACTION_START"
            }
            try {
                context.startForegroundService(serviceIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service on boot", e)
            }
        } else {
            Log.i(TAG, "Voice service was not enabled — skipping")
        }
    }
}
