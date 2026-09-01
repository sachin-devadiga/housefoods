package com.example.housefoods.mealvoice

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between Flutter and Android native MEAL voice service.
 *
 * MethodChannel: Flutter → Android commands
 * EventChannel: Android → Flutter events
 */
class MealVoiceBridge(
    private val flutterEngine: FlutterEngine,
    private val service: MealVoiceService
) {
    companion object {
        private const val TAG = "MEAL_Bridge"
        private const val METHOD_CHANNEL = "com.mealin/voice_method"
        private const val EVENT_CHANNEL = "com.mealin/voice_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    fun attach() {
        // MethodChannel: receive commands from Flutter
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        // EventChannel: send events to Flutter
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.i(TAG, "EventChannel connected")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.i(TAG, "EventChannel disconnected")
            }
        })

        Log.i(TAG, "Bridge attached")
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        Log.i(TAG, "Bridge detached")
    }

    private fun handleMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestMicrophonePermission" -> {
                val granted = service.requestMicrophonePermission()
                result.success(granted)
            }
            "startListening" -> {
                val started = service.startListening()
                result.success(started)
            }
            "stopListening" -> {
                val stopped = service.stopListening()
                result.success(stopped)
            }
            "isMicrophoneAvailable" -> {
                val available = service.isMicrophoneAvailable()
                result.success(available)
            }
            "getStatus" -> {
                val status = service.getStatus()
                result.success(status)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /** Send an event to Flutter via EventChannel */
    fun sendEvent(type: String, data: Any? = null) {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
        )
        if (data != null) {
            event["data"] = data
        }
        flutterEngine.mainHandler.post {
            eventSink?.success(event)
        }
    }

    /** Send wake word detected event to Flutter */
    fun sendWakeWordDetected() {
        sendEvent("wakeWordDetected", System.currentTimeMillis())
    }

    /** Send state changed event to Flutter */
    fun sendStateChanged(stateIndex: Int) {
        sendEvent("stateChanged", stateIndex)
    }

    /** Send error event to Flutter */
    fun sendError(message: String) {
        sendEvent("error", message)
    }

    /** Send log event to Flutter */
    fun sendLog(message: String) {
        sendEvent("log", message)
    }
}
