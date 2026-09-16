package com.example.housefoods.mealvoice

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between Flutter and Android MEAL voice engine.
 * All native→Flutter events go through EventChannel (not broadcast).
 */
class MealVoiceBridge(
    private val flutterEngine: FlutterEngine,
    private val service: MealVoiceService
) {
    companion object {
        private const val METHOD_CHANNEL = "com.mealin/voice_method"
        private const val EVENT_CHANNEL = "com.mealin/voice_events"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    fun attach() {
        service.bridge = this

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestMicrophonePermission" -> result.success(true)
                "startListening" -> {
                    Log.i("MEAL_Bridge", "startListening called from Flutter")
                    result.success(service.startVoiceService())
                }
                "stopListening" -> {
                    Log.i("MEAL_Bridge", "stopListening called from Flutter")
                    service.stopVoiceService()
                    result.success(true)
                }
                "stopEngine" -> {
                    Log.i("MEAL_Bridge", "stopEngine called from Flutter")
                    service.stopEngine()
                    result.success(true)
                }
                "startCommandCapture" -> {
                    Log.i("MEAL_Bridge", "startCommandCapture called from Flutter")
                    service.startCommandCapture()
                    result.success(true)
                }
                "stopCommandCapture" -> {
                    Log.i("MEAL_Bridge", "stopCommandCapture called from Flutter")
                    service.stopCommandCapture()
                    result.success(true)
                }
                "restartWakeWordListening" -> {
                    Log.i("MEAL_Bridge", "restartWakeWordListening called from Flutter")
                    service.restartWakeWordListening()
                    result.success(true)
                }
                "isMicrophoneAvailable" -> result.success(true)
                "isBatteryOptimizationIgnored" -> result.success(isBatteryOptimizationIgnored())
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isVoiceEnabledOnBoot" -> result.success(isVoiceEnabledOnBoot())
                "getStatus" -> result.success(mapOf(
                    "running" to service.isRunning,
                    "engine" to "SpeechRecognizer",
                    "batteryOptimizationIgnored" to isBatteryOptimizationIgnored()
                ))
                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })
    }

    fun detach() {
        service.bridge = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }

    /**
     * Send event to Flutter via EventChannel.
     */
    fun sendEvent(type: String, data: Any? = null) {
        val event = mutableMapOf<String, Any?>("type" to type)
        if (data != null) event["data"] = data
        Log.i("MEAL_Bridge", "sendEvent: type=$type, data=$data")
        mainHandler.post {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                // EventChannel may be closed — silently ignore
            }
        }
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        val context = service.applicationContext
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true // Pre-M devices don't have this restriction
        }
    }

    private fun requestBatteryOptimizationExemption() {
        try {
            val context = service.applicationContext
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !pm.isIgnoringBatteryOptimizations(context.packageName)) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                Log.i("MEAL_Bridge", "Battery optimization exemption requested")
            }
        } catch (e: Exception) {
            Log.e("MEAL_Bridge", "Failed to request battery optimization exemption", e)
        }
    }

    private fun isVoiceEnabledOnBoot(): Boolean {
        val context = service.applicationContext
        val prefs = context.getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("voice_enabled", false)
    }
}
