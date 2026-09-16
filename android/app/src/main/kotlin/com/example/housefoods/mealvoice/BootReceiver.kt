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
                // Post a notification telling the user to open the app.
                Log.w(TAG, "Android 14+: posting notification for manual restart")
                try {
                    val channel = android.app.NotificationChannel(
                        "meal_voice_restart",
                        "MEAL Voice Restart",
                        android.app.NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Notifies you to restart MEAL voice after boot"
                    }
                    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    manager.createNotificationChannel(channel)

                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val pendingIntent = android.app.PendingIntent.getActivity(
                        context, 2, launchIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                    val notification = androidx.core.app.NotificationCompat.Builder(context, "meal_voice_restart")
                        .setContentTitle("MEAL Voice needs restart")
                        .setContentText("Tap to open MEAL and re-enable voice assistant")
                        .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                        .setContentIntent(pendingIntent)
                        .setAutoCancel(true)
                        .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                        .build()
                    manager.notify(9996, notification)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to post restart notification", e)
                }
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
