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

class MealVoiceService : Service() {

    companion object {
        private const val TAG = "MEAL_Service"
        private const val CHANNEL_ID = "meal_voice_channel"
        private const val NOTIFICATION_ID = 9999

        var isRunning = false
            private set
    }

    private var wakeWordEngine: WakeWordEngine? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_STOP" -> stopVoiceService()
            else -> startVoiceService()
        }
        return START_STICKY
    }

    override fun onDestroy() {
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
            onEvent = WakeWordEngine.OnEngineEvent { type, data -> sendEvent(type, data?.toString() ?: "") }
        )

        val started = wakeWordEngine!!.start()
        if (!started) {
            Log.e(TAG, "Failed to start")
            sendEvent("error", "Failed to start microphone")
            stopSelf()
            return false
        }

        isRunning = true
        sendEvent("stateChanged", com.example.housefoods.mealvoice.MealVoiceState.LISTENING_FOR_WAKE_WORD.ordinal.toString())
        Log.i(TAG, "Started successfully")
        return true
    }

    fun stopVoiceService() {
        wakeWordEngine?.stop()
        wakeWordEngine?.release()
        wakeWordEngine = null

        sendEvent("stateChanged", MealVoiceState.STOPPED.ordinal.toString())
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun onWakeWordDetected() {
        Log.i(TAG, "=== WAKE WORD DETECTED ===")
        sendEvent("wakeWordDetected", System.currentTimeMillis().toString())
        updateNotification("Wake word detected! Listening...")
    }

    private fun sendEvent(type: String, data: String) {
        val intent = Intent("com.mealin.VOICE_EVENT")
        intent.putExtra("event_type", type)
        intent.putExtra("event_data", data)
        sendBroadcast(intent)
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

enum class MealVoiceState {
    IDLE, INITIALIZING, LISTENING_FOR_WAKE_WORD, WAKE_DETECTED,
    LISTENING_TO_USER, PROCESSING, SPEAKING, ERROR, STOPPED
}
