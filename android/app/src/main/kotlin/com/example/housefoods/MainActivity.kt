package com.example.housefoods

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Main Activity that caches the Flutter engine and registers
 * MEAL voice channels so they work before the service starts.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MEAL_MainActivity"
        private const val METHOD_CHANNEL = "com.mealin/voice_method"
        private const val EVENT_CHANNEL = "com.mealin/voice_events"
        private const val ENGINE_ID = "main_engine"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var voiceServiceRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the Flutter engine so the foreground service can access it
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        Log.i(TAG, "Flutter engine cached")

        // Register MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestMicrophonePermission" -> {
                    // Return true - actual permission handled by permission_handler on Flutter side
                    result.success(true)
                }
                "startListening" -> {
                    // Start the foreground service
                    val intent = android.content.Intent(this, com.example.housefoods.mealvoice.MealVoiceService::class.java)
                    intent.action = "ACTION_START"
                    startForegroundService(intent)
                    voiceServiceRunning = true
                    result.success(true)
                }
                "stopListening" -> {
                    val intent = android.content.Intent(this, com.example.housefoods.mealvoice.MealVoiceService::class.java)
                    intent.action = "ACTION_STOP"
                    startService(intent)
                    voiceServiceRunning = false
                    result.success(true)
                }
                "isMicrophoneAvailable" -> {
                    val pm = packageManager
                    val hasMic = pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_MICROPHONE)
                    result.success(hasMic)
                }
                "getStatus" -> {
                    result.success(mapOf(
                        "running" to voiceServiceRunning,
                        "engine" to "SpeechRecognizer",
                        "micAvailable" to packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_MICROPHONE)
                    ))
                }
                else -> result.notImplemented()
            }
        }

        // Register EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.i(TAG, "EventChannel connected")
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Listen for broadcast from the service
        registerReceiver()
    }

    private var serviceReceiver: android.content.BroadcastReceiver? = null

    private fun registerReceiver() {
        serviceReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: android.content.Intent?) {
                val type = intent?.getStringExtra("event_type") ?: return
                val data = intent.getStringExtra("event_data")
                mainHandler.post {
                    val event = mutableMapOf<String, Any?>("type" to type)
                    if (data != null) event["data"] = data
                    eventSink?.success(event)
                }
            }
        }
        val filter = android.content.IntentFilter("com.mealin.VOICE_EVENT")
        registerReceiver(serviceReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        serviceReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }
}
