package com.example.housefoods.mealvoice

import android.os.Handler
import android.os.Looper
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
                "startListening" -> result.success(service.startVoiceService())
                "stopListening" -> {
                    service.stopVoiceService()
                    result.success(true)
                }
                "startCommandCapture" -> {
                    service.startCommandCapture()
                    result.success(true)
                }
                "stopCommandCapture" -> {
                    service.stopCommandCapture()
                    result.success(true)
                }
                "restartWakeWordListening" -> {
                    service.restartWakeWordListening()
                    result.success(true)
                }
                "isMicrophoneAvailable" -> result.success(true)
                "getStatus" -> result.success(mapOf(
                    "running" to service.isRunning,
                    "engine" to "SpeechRecognizer"
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
        mainHandler.post {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                // EventChannel may be closed — silently ignore
            }
        }
    }
}
