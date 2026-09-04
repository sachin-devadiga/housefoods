package com.example.housefoods.mealvoice

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

        private var instance: MealVoiceService? = null

        fun getInstance(): MealVoiceService? = instance
    }

    // FIX #32: Instance-level state, not static
    var isRunning = false
        private set

    private var wakeWordEngine: SpeechRecognizerWakeWordEngine? = null

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
            "ACTION_START_COMMAND_CAPTURE" -> startCommandCapture()
            "ACTION_STOP_COMMAND_CAPTURE" -> stopCommandCapture()
            "ACTION_RESTART_WAKE_WORD" -> restartWakeWordListening()
            else -> startVoiceService()
        }
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

        val notification = buildNotification("Listening for 'Hi MEAL'...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

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

        bridge?.sendEvent("stateChanged", "14") // STOPPED
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Called when "Hi MEAL" is detected.
     * Switches from wake-word mode to command capture mode.
     */
    private fun onWakeWordDetected() {
        Log.i(TAG, "=== WAKE WORD DETECTED ===")
        bridge?.sendEvent("wakeWordDetected", System.currentTimeMillis().toString())
        updateNotification("Wake word detected! Listening for command...")

        // Switch to command capture mode (only once — engine guards against double-start)
        wakeWordEngine?.startCommandCapture()
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
}
