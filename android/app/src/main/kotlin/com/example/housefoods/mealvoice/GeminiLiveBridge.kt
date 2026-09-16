package com.example.housefoods.mealvoice

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Bridge between Flutter and native Gemini Live engine.
 * Handles MethodChannel calls and EventChannel events.
 */
class GeminiLiveBridge(
    private val flutterEngine: FlutterEngine,
    private val context: Context
) {
    companion object {
        private const val TAG = "MEAL_GeminiLiveBridge"
        private const val METHOD_CHANNEL = "com.mealin/gemini_live"
        private const val EVENT_CHANNEL = "com.mealin/gemini_live_events"
    }

    private var engine: GeminiLiveEngine? = null
    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    fun attach() {
        engine = GeminiLiveEngine(context)
        engine?.setCallback(object : GeminiLiveEngine.Callback {
            override fun onConnected() {
                sendEvent("connected")
            }

            override fun onDisconnected(reason: String) {
                sendEvent("disconnected", reason)
            }

            override fun onTranscription(text: String, isFinal: Boolean) {
                sendEvent("transcription", mapOf("text" to text, "isFinal" to isFinal))
            }

            override fun onResponse(text: String) {
                sendEvent("response", text)
            }

            override fun onFunctionCall(name: String, args: JSONObject) {
                val argsMap = mutableMapOf<String, Any?>()
                val keys = args.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    argsMap[key] = args.opt(key)
                }
                sendEvent("functionCall", mapOf("name" to name, "args" to argsMap))
            }

            override fun onAudioOutput(audioData: ByteArray) {
                sendEvent("audioOutput", audioData.toList())
            }

            override fun onError(message: String, recoverable: Boolean) {
                sendEvent("error", message)
            }

            override fun onStateChange(state: String) {
                sendEvent("state", state)
            }
        })

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val config = call.arguments as? Map<*, *>
                    if (config != null) {
                        val json = JSONObject(config)
                        val connected = engine?.connect(json) ?: false
                        result.success(connected)
                    } else {
                        result.error("INVALID_ARGS", "Config is required", null)
                    }
                }

                "disconnect" -> {
                    engine?.disconnect()
                    result.success(true)
                }

                "sendText" -> {
                    val text = call.argument<String>("text") ?: ""
                    engine?.sendText(text)
                    result.success(true)
                }

                "sendAudio" -> {
                    val audio = call.argument<List<Int>>("audio") ?: emptyList()
                    val byteArray = ByteArray(audio.size)
                    for (i in audio.indices) {
                        byteArray[i] = audio[i].toByte()
                    }
                    engine?.sendAudio(byteArray)
                    result.success(true)
                }

                "sendFunctionResponse" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    val response = call.argument<Map<String, Any>>("response") ?: emptyMap()
                    engine?.sendFunctionResponse(callId, JSONObject(response))
                    result.success(true)
                }

                "isActive" -> {
                    result.success(engine?.isActive() ?: false)
                }

                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        Log.i(TAG, "GeminiLive bridge attached")
    }

    fun detach() {
        engine?.disconnect()
        engine = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }

    private fun sendEvent(type: String, data: Any? = null) {
        val event = mutableMapOf<String, Any?>("type" to type)
        if (data != null) event["data"] = data
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                eventSink?.success(event)
            } catch (e: Exception) {
                // EventChannel may be closed
            }
        }
    }
}
