package com.example.housefoods.mealvoice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.housefoods.MainActivity
import com.example.housefoods.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Foreground Service for MEAL wake-word detection.
 *
 * Runs continuously with a persistent notification.
 * Captures microphone audio and detects "Hi MEAL" wake word.
 *
 * On Android 14+ requires FOREGROUND_SERVICE_MICROPHONE permission.
 */
class MealVoiceService : Service() {

    companion object {
        private const val TAG = "MEAL_Service"
        private const val CHANNEL_ID = "meal_voice_channel"
        private const val NOTIFICATION_ID = 9999

        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        var isRunning = false
            private set

        private var flutterEngine: FlutterEngine? = null
        private var bridge: MealVoiceBridge? = null
    }

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private val isRecording = AtomicBoolean(false)
    private var wakeWordEngine: WakeWordEngine? = null

    // Simple keyword detection state
    private var silenceFrameCount = 0
    private val SILENCE_THRESHOLD = 500
    private val MAX_SILENCE_FRAMES = 50

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_START" -> startDetection()
            "ACTION_STOP" -> stopDetection()
            else -> startDetection()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopDetection()
        super.onDestroy()
    }

    private fun startDetection() {
        if (isRunning) {
            Log.i(TAG, "Already running")
            return
        }

        Log.i(TAG, "Starting wake-word detection")

        // Start as foreground service with microphone type
        val notification = buildNotification("Listening for 'Hi MEAL'...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Get Flutter engine from cache
        flutterEngine = FlutterEngineCache.getInstance().get("main_engine")
        if (flutterEngine == null) {
            Log.e(TAG, "Flutter engine not cached")
            stopSelf()
            return
        }

        // Set up bridge
        bridge = MealVoiceBridge(flutterEngine!!, this)
        bridge?.attach()

        // Initialize wake word engine
        wakeWordEngine = PorcupineWakeWordEngine()
        wakeWordEngine?.initialize(
            context = this,
            onDetected = WakeWordEngine.OnWakeWordDetected {
                onWakeWordDetected()
            },
            onEvent = WakeWordEngine.OnEngineEvent { type, data ->
                bridge?.sendLog("Engine event: $type = $data")
            }
        )

        // Start audio capture
        if (!startAudioCapture()) {
            Log.e(TAG, "Failed to start audio capture")
            bridge?.sendError("Failed to start microphone")
            stopSelf()
            return
        }

        // Start wake word engine
        wakeWordEngine?.start()

        isRunning = true
        bridge?.sendStateChanged(MealVoiceState.LISTENING_FOR_WAKE_WORD.ordinal)

        Log.i(TAG, "Wake-word detection started successfully")
    }

    private fun stopDetection() {
        if (!isRunning) return

        Log.i(TAG, "Stopping wake-word detection")

        isRecording.set(false)
        recordingThread?.interrupt()
        recordingThread = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        wakeWordEngine?.stop()
        wakeWordEngine?.release()
        wakeWordEngine = null

        bridge?.sendStateChanged(MealVoiceState.STOPPED.ordinal)
        bridge?.detach()
        bridge = null

        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startAudioCapture(): Boolean {
        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size: $minBufferSize")
            return false
        }

        val bufferSize = minBufferSize * 2

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Microphone permission not granted", e)
            return false
        }

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord failed to initialize")
            return false
        }

        isRecording.set(true)
        audioRecord?.startRecording()

        recordingThread = Thread({
            captureAudio()
        }, "MEAL-AudioCapture")
        recordingThread?.start()

        Log.i(TAG, "Audio capture started (buffer: $bufferSize)")
        return true
    }

    private fun captureAudio() {
        val buffer = ShortArray(1024)

        while (isRecording.get()) {
            try {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                if (read > 0) {
                    // Calculate audio level (RMS)
                    var sum = 0L
                    for (i in 0 until read) {
                        sum += buffer[i].toLong() * buffer[i].toLong()
                    }
                    val rms = Math.sqrt(sum.toDouble() / read).toInt()

                    // Simple voice activity detection
                    if (rms > SILENCE_THRESHOLD) {
                        silenceFrameCount = 0
                        // TODO: Feed audio frames to Porcupine engine for wake-word detection
                        // wakeWordEngine?.processFrame(buffer, read)
                    } else {
                        silenceFrameCount++
                    }
                }
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                Log.e(TAG, "Audio capture error", e)
                break
            }
        }
    }

    private fun onWakeWordDetected() {
        Log.i(TAG, "=== WAKE WORD DETECTED ===")
        bridge?.sendWakeWordDetected()
        updateNotification("Wake word detected! Listening...")

        // Play a subtle chime to indicate detection
        // Future: Start STT session here
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "MEAL Voice Assistant",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps MEAL voice assistant running to detect 'Hi MEAL'"
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

/** Mirror of Flutter MealVoiceState enum for native side */
enum class MealVoiceState {
    IDLE,
    INITIALIZING,
    LISTENING_FOR_WAKE_WORD,
    WAKE_DETECTED,
    LISTENING_TO_USER,
    PROCESSING,
    SPEAKING,
    ERROR,
    STOPPED
}
