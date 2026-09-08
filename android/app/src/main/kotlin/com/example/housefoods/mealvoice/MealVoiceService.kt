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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
    @Volatile
    var isRunning = false
        private set

    private var wakeWordEngine: SpeechRecognizerWakeWordEngine? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var nativeProcessor: VoiceNativeProcessor? = null
    @Volatile
    private var isNativeProcessing = false

    // Bridge reference — set by MainActivity (null when in separate process)
    var bridge: MealVoiceBridge? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "Service created (process: ${android.os.Process.myPid()})")
        createNotificationChannel()

        // Initialize native processor for background command handling
        nativeProcessor = VoiceNativeProcessor(this)
        nativeProcessor?.initialize {
            Log.i(TAG, "Native processor TTS ready")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Null intent = system restart after process death (START_STICKY)
        if (intent == null) {
            val prefs = getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
            val wasEnabled = prefs.getBoolean("voice_enabled", false)
            if (wasEnabled) {
                Log.i(TAG, "System restart (null intent) — voice was enabled, auto-starting")
                startVoiceService()
            } else {
                Log.i(TAG, "System restart but voice not enabled — stopping")
                stopSelf()
            }
            return START_STICKY
        }

        when (intent.action) {
            "ACTION_STOP" -> stopVoiceService()
            "ACTION_START" -> startVoiceService()
            "ACTION_CREATE_ONLY" -> {
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
                            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
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
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        nativeProcessor?.shutdown()
        nativeProcessor = null
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
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed; voice service will not start", e)
            stopSelf()
            return false
        }

        acquireWakeLock()
        scheduleRestartAlarm()

        wakeWordEngine = SpeechRecognizerWakeWordEngine()
        wakeWordEngine!!.initialize(
            context = this,
            onDetected = WakeWordEngine.OnWakeWordDetected { onWakeWordDetected() },
            onEvent = WakeWordEngine.OnEngineEvent { type, data ->
                bridge?.sendEvent(type, data?.toString() ?: "")
            }
        )
        // Native command callback — fires when bridge is dead
        wakeWordEngine!!.setCommandCapturedListener(WakeWordEngine.OnCommandCaptured { transcript ->
            Log.i(TAG, "Native command captured via engine callback: $transcript")
            if (bridge == null) {
                processNativeCommand(transcript)
            }
        })

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
        bridge?.sendEvent("stateChanged", "1") // IDLE
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
            // Bridge is dead — process command natively
            Log.i(TAG, "Bridge is null — processing command natively")
            updateNotification("Wake word detected! Listening for your order...")
            startNativeCommandCapture()
        }
    }

    /**
     * Capture command via native SpeechRecognizer when Flutter is dead,
     * then process it entirely in native Kotlin.
     * Uses the SAME SpeechRecognizer from wake word engine — just swaps listener.
     */
    private fun startNativeCommandCapture() {
        if (isNativeProcessing) {
            Log.i(TAG, "Already processing natively")
            return
        }
        isNativeProcessing = true
        playConfirmationBeep()

        // Use the wake word engine's startCommandCapture (swaps listener, keeps mic alive)
        val started = wakeWordEngine?.startCommandCapture() ?: false
        if (!started) {
            Log.e(TAG, "Failed to start command capture via engine")
            isNativeProcessing = false
            // Fallback: create a standalone recognizer
            startStandaloneCommandCapture()
            return
        }

        // Set timeout for native processing
        android.os.Handler(Looper.getMainLooper()).postDelayed({
            if (isNativeProcessing) {
                Log.w(TAG, "Native command capture timed out")
                isNativeProcessing = false
                updateNotification("Listening timed out. Say 'Hi MEAL' to try again.")
                wakeWordEngine?.stopCommandCapture()
                restartWakeWordListening()
            }
        }, 15000)
    }

    /**
     * Fallback: standalone recognizer when wake word engine is not available.
     */
    private fun startStandaloneCommandCapture() {
        try {
            val recognizer = android.speech.SpeechRecognizer.createSpeechRecognizer(this)
            recognizer?.setRecognitionListener(object : android.speech.RecognitionListener {
                override fun onReadyForSpeech(params: android.os.Bundle?) {
                    Log.i(TAG, "Standalone STT: Ready for speech")
                    updateNotification("Listening... Speak your command")
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    Log.i(TAG, "Standalone STT: End of speech")
                    updateNotification("Processing your command...")
                }
                override fun onError(error: Int) {
                    Log.e(TAG, "Standalone STT error: $error")
                    isNativeProcessing = false
                    updateNotification("Didn't catch that. Say 'Hi MEAL' to try again.")
                    restartWakeWordListening()
                }
                override fun onResults(results: android.os.Bundle?) {
                    val matches = results?.getStringArrayList(android.speech.SpeechRecognizer.RESULTS_RECOGNITION)
                    val transcript = matches?.firstOrNull() ?: ""
                    Log.i(TAG, "Standalone STT result: $transcript")
                    if (transcript.isNotEmpty()) {
                        processNativeCommand(transcript)
                    } else {
                        isNativeProcessing = false
                        updateNotification("Didn't catch that. Say 'Hi MEAL' to try again.")
                        restartWakeWordListening()
                    }
                }
                override fun onPartialResults(partialResults: android.os.Bundle?) {}
                override fun onEvent(eventType: Int, params: android.os.Bundle?) {}
            })

            val intent = android.content.Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                putExtra(android.speech.RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(android.speech.RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            }
            recognizer?.startListening(intent)

            android.os.Handler(Looper.getMainLooper()).postDelayed({
                if (isNativeProcessing) {
                    recognizer?.cancel()
                    isNativeProcessing = false
                    updateNotification("Listening timed out. Say 'Hi MEAL' to try again.")
                    restartWakeWordListening()
                }
            }, 12000)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start standalone STT", e)
            isNativeProcessing = false
            launchAppForCommand()
        }
    }

    /**
     * Process a command entirely natively: call Gemini, execute actions, speak response.
     */
    private fun processNativeCommand(transcript: String) {
        val processor = nativeProcessor
        if (processor == null) {
            Log.e(TAG, "Native processor not initialized")
            isNativeProcessing = false
            launchAppForCommand()
            return
        }

        val authToken = processor.getAuthToken()
        if (authToken.isNullOrEmpty()) {
            Log.e(TAG, "No auth token — cannot process natively")
            isNativeProcessing = false
            launchAppForCommand()
            return
        }

        Thread {
            try {
                Log.i(TAG, "Calling Gemini with: $transcript")
                val geminiResponse = processor.callGemini(
                    prompt = transcript,
                    authToken = authToken,
                )

                if (geminiResponse == null) {
                    Log.e(TAG, "Gemini returned null")
                    isNativeProcessing = false
                    updateNotification("Sorry, I had trouble processing that. Say 'Hi MEAL' to try again.")
                    restartWakeWordListening()
                    return@Thread
                }

                val (responseText, actions) = processor.parseGeminiResponse(geminiResponse)
                Log.i(TAG, "Gemini response: $responseText (${actions.size} actions)")

                // Check if there are actions that need Flutter (cart, order, search)
                val needsFlutter = actions.any { action ->
                    val type = action.optString("type", "")
                    type == "add_to_cart" || type == "remove_from_cart" ||
                    type == "clear_cart" || type == "place_order" ||
                    type == "search_menu" || type == "show_cart"
                }

                if (needsFlutter) {
                    // Actions require Flutter — launch the app
                    Log.i(TAG, "Actions require Flutter — launching app")
                    // Save the command so Flutter can pick it up
                    getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .putBoolean("pending_wake_word", true)
                        .putString("pending_command", transcript)
                        .apply()
                    isNativeProcessing = false
                    processor.speak(responseText) {
                        launchAppForCommand()
                    }
                    return@Thread
                }

                // Pure conversational response — speak it and go back to listening
                processor.speak(responseText) {
                    Log.i(TAG, "TTS done — restarting wake word")
                    isNativeProcessing = false
                    updateNotification("Listening for 'Hi MEAL'...")
                    restartWakeWordListening()
                }

                updateNotification(responseText)

            } catch (e: Exception) {
                Log.e(TAG, "Native processing failed", e)
                isNativeProcessing = false
                updateNotification("Something went wrong. Say 'Hi MEAL' to try again.")
                restartWakeWordListening()
            }
        }.start()
    }

    /**
     * Launch the main app to process a command (fallback when native can't handle it).
     */
    private fun launchAppForCommand() {
        val launchIntent = Intent(this, com.example.housefoods.MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("meal_voice_wake_word", true)
        }
        try {
            startActivity(launchIntent)
            showWakeWordNotification()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app", e)
            showWakeWordNotification()
        }
    }

    /**
     * Start command capture (called from Flutter via MethodChannel).
     * Plays a confirmation beep to signal "speak now".
     */
    fun startCommandCapture() {
        playConfirmationBeep()
        wakeWordEngine?.startCommandCapture()
    }

    /**
     * Play a short confirmation tone to signal the user to speak.
     */
    private fun playConfirmationBeep() {
        try {
            val toneGenerator = android.media.ToneGenerator(
                android.media.AudioManager.STREAM_NOTIFICATION,
                80
            )
            toneGenerator.startTone(android.media.ToneGenerator.TONE_PROP_ACK, 150)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                toneGenerator.release()
            }, 200)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to play confirmation beep: ${e.message}")
        }
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
     * Uses setAlarmClock which is exempt from Doze mode.
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
            // Use setAlarmClock — exempt from Doze, survives process death
            val alarmIntent = Intent(this, BootReceiver::class.java).apply {
                action = BootReceiver.ACTION_SERVICE_RESTART
            }
            val alarmPending = PendingIntent.getBroadcast(
                this, 9998, alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val triggerTime = System.currentTimeMillis() + 5 * 60 * 1000L
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerTime, alarmPending),
                pendingIntent
            )
            Log.i(TAG, "Restart alarm scheduled (setAlarmClock, every 5 min)")
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
