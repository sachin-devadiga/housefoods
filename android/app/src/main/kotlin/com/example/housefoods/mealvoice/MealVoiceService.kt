package com.example.housefoods.mealvoice

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.housefoods.MainActivity

/**
 * Foreground service for MEAL Voice Engine.
 *
 * FIX #33: Removed broken broadcast sendEvent — all events go through MealVoiceBridge.
 * FIX #31: restartWakeWordListening actually restarts via engine.restartWakeWordListening().
 * FIX #32: isRunning is now instance-level, not static.
 */
class MealVoiceService : Service() {

    companion object {
        private const val TAG = "MEAL_Service"
        private const val CHANNEL_ID = "meal_voice_channel"
        private const val NOTIFICATION_ID = 9999
        private const val WAKE_WORD_NOTIFICATION_ID = 9998

        private var instance: MealVoiceService? = null

        fun getInstance(): MealVoiceService? = instance

        fun hasPendingWakeWord(context: Context): Boolean {
            return context.getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
                .getBoolean("pending_wake_word", false)
        }

        fun clearPendingWakeWord(context: Context) {
            context.getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
                .edit().remove("pending_wake_word").apply()
        }
    }

    // FIX #32: Instance-level state, not static
    var isRunning = false
        private set

    private var wakeWordEngine: SpeechRecognizerWakeWordEngine? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Bridge reference — set by MainActivity
    var bridge: MealVoiceBridge? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_STOP" -> stopVoiceService()
            "ACTION_START" -> startVoiceService()
            "ACTION_CREATE_ONLY" -> {
                // Service created — check if voice was previously enabled
                val prefs = getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
                val wasEnabled = prefs.getBoolean("voice_enabled", false)
                if (wasEnabled) {
                    Log.i(TAG, "Voice was enabled — auto-starting engine")
                    startVoiceService()
                } else {
                    Log.i(TAG, "Created only — waiting for Flutter to start listening")
                    val notification = buildNotification("MEAL ready — tap to open")
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                        } else {
                            startForeground(NOTIFICATION_ID, notification)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "startForeground failed", e)
                    }
                }
            }
            "ACTION_RESTART_ENGINE" -> {
                Log.i(TAG, "Restart command received — restarting engine")
                if (!isRunning) {
                    startVoiceService()
                } else {
                    restartWakeWordListening()
                }
            }
            "ACTION_START_COMMAND_CAPTURE" -> startCommandCapture()
            "ACTION_STOP_COMMAND_CAPTURE" -> stopCommandCapture()
            "ACTION_RESTART_WAKE_WORD" -> restartWakeWordListening()
            else -> {
                Log.i(TAG, "Unknown action: ${intent?.action}")
            }
        }
        // START_STICKY: if service is killed, Android restarts it
        // Our BootReceiver + periodic alarm handle the actual engine restart
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        stopVoiceService()
        super.onDestroy()
    }

    fun startVoiceService(): Boolean {
        if (isRunning) {
            Log.i(TAG, "Already running")
            return true
        }

        Log.i(TAG, "Starting wake-word detection")

        // Save user preference for auto-start on boot
        getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
            .edit().putBoolean("voice_enabled", true).apply()

        val notification = buildNotification("Listening for 'Hi MEAL'...")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed, continuing without foreground", e)
        }

        acquireWakeLock()
        scheduleRestartAlarm()

        wakeWordEngine = SpeechRecognizerWakeWordEngine()
        wakeWordEngine!!.initialize(
            context = this,
            onDetected = WakeWordEngine.OnWakeWordDetected { onWakeWordDetected() },
            onEvent = WakeWordEngine.OnEngineEvent { type, data ->
                // FIX #33: All events go through bridge (EventChannel), not broadcast
                bridge?.sendEvent(type, data?.toString() ?: "")
            }
        )

        val started = wakeWordEngine!!.start()
        if (!started) {
            Log.e(TAG, "Failed to start")
            bridge?.sendEvent("error", "Failed to start microphone")
            stopSelf()
            return false
        }

        isRunning = true
        bridge?.sendEvent("stateChanged", "3") // LISTENING_FOR_WAKE_WORD
        Log.i(TAG, "Started successfully")
        return true
    }

    fun stopVoiceService() {
        wakeWordEngine?.stop()
        wakeWordEngine?.release()
        wakeWordEngine = null

        releaseWakeLock()
        cancelRestartAlarm()

        // Save user preference — service was stopped
        getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
            .edit().putBoolean("voice_enabled", false).apply()

        bridge?.sendEvent("stateChanged", "14") // STOPPED
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Stop the speech engine but keep the service and bridge alive.
     * Used when switching from wake-word mode to command capture mode.
     */
    fun stopEngine() {
        Log.i(TAG, "Stopping engine (keeping service alive)")
        wakeWordEngine?.stop()
        wakeWordEngine?.release()
        wakeWordEngine = null
        releaseWakeLock()
        isRunning = false
    }

    /**
     * Called when "Hi MEAL" is detected.
     * Only notifies Flutter — Flutter decides whether to use native or Sarvam for command.
     */
    private fun onWakeWordDetected() {
        Log.i(TAG, "=== WAKE WORD DETECTED ===")

        if (bridge != null) {
            // Bridge is alive — send event directly to Flutter
            bridge?.sendEvent("wakeWordDetected", System.currentTimeMillis().toString())
            updateNotification("Wake word detected! Listening for command...")
        } else {
            // Bridge is dead (app killed) — launch app to process the command
            Log.i(TAG, "Bridge is null — launching app to process wake word")
            getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
                .edit().putBoolean("pending_wake_word", true).apply()

            // Launch the app — it will pick up pending_wake_word and process it
            val launchIntent = Intent(this, com.example.housefoods.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("meal_voice_wake_word", true)
            }
            try {
                startActivity(launchIntent)
                showWakeWordNotification()
                updateNotification("Opening MEAL to process your command...")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch app", e)
                showWakeWordNotification()
            }
        }
    }

    /**
     * Start command capture (called from Flutter via MethodChannel).
     */
    fun startCommandCapture() {
        wakeWordEngine?.startCommandCapture()
    }

    /**
     * Stop command capture (called from Flutter via MethodChannel).
     */
    fun stopCommandCapture() {
        wakeWordEngine?.stopCommandCapture()
    }

    /**
     * FIX #31: Actually restart wake-word listening via the engine.
     */
    fun restartWakeWordListening() {
        Log.i(TAG, "Restarting wake-word listening")
        updateNotification("Listening for 'Hi MEAL'...")
        wakeWordEngine?.restartWakeWordListening()
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "mealvoice:wakelock"
            ).apply {
                acquire(60 * 60 * 1000L) // 1 hour max, will be released when service stops
            }
            Log.i(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.i(TAG, "Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }

    /**
     * Schedule a periodic alarm to restart this service if it gets killed.
     * Fires every 5 minutes. The alarm receiver (BootReceiver) checks
     * if the service is already running before restarting.
     */
    private fun scheduleRestartAlarm() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, BootReceiver::class.java).apply {
                action = BootReceiver.ACTION_SERVICE_RESTART
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this, 9997, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Repeat every 5 minutes
            alarmManager.setRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                System.currentTimeMillis() + 5 * 60 * 1000L,
                5 * 60 * 1000L,
                pendingIntent
            )
            Log.i(TAG, "Restart alarm scheduled (every 5 min)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule restart alarm", e)
        }
    }

    /**
     * Cancel the periodic restart alarm.
     */
    private fun cancelRestartAlarm() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, BootReceiver::class.java).apply {
                action = BootReceiver.ACTION_SERVICE_RESTART
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this, 9997, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.i(TAG, "Restart alarm cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel restart alarm", e)
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "MEAL Voice Assistant",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps MEAL voice assistant running"
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)

        // Separate channel for wake word alerts (high importance so it heads-up)
        val alertChannel = NotificationChannel(
            "meal_voice_wake_word",
            "MEAL Wake Word Alert",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifies when MEAL hears 'Hi MEAL'"
        }
        manager.createNotificationChannel(alertChannel)
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MEAL")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun showWakeWordNotification() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("meal_voice_wake_word", true)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, "meal_voice_wake_word")
            .setContentTitle("MEAL heard you!")
            .setContentText("Tap to place your order")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(WAKE_WORD_NOTIFICATION_ID, notification)
    }
}
