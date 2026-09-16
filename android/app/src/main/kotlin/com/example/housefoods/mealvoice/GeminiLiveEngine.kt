package com.example.housefoods.mealvoice

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

/**
 * Gemini Live Voice Engine.
 *
 * Connects to Google's Gemini Multimodal Live API via WebSocket for real-time
 * voice conversation. Audio is captured from the microphone, sent to Gemini,
 * and Gemini's audio response is played back through AudioTrack.
 *
 * Architecture: Device ↔ Gemini Live WebSocket (direct, no backend proxy).
 * Backend provides session config (API key, model, tools) via REST endpoint.
 */
class GeminiLiveEngine(private val context: Context) {

    companion object {
        private const val TAG = "MEAL_GeminiLive"
        private const val WS_URL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val FRAME_SIZE = 320 // 20ms at 16kHz
    }

    interface Callback {
        fun onConnected()
        fun onDisconnected(reason: String)
        fun onTranscription(text: String, isFinal: Boolean)
        fun onResponse(text: String)
        fun onFunctionCall(name: String, args: JSONObject)
        fun onAudioOutput(audioData: ByteArray)
        fun onError(message: String, recoverable: Boolean)
        fun onStateChange(state: String)
    }

    private var callback: Callback? = null
    private val isRunning = AtomicBoolean(false)
    private val isRecording = AtomicBoolean(false)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingThread: Thread? = null
    private var wsThread: Thread? = null

    // WebSocket connection
    private var wsConnection: java.net.URLConnection? = null
    private var wsOutputStream: java.io.OutputStream? = null
    private var wsInputStream: java.io.InputStream? = null

    // Session config
    private var apiKey: String = ""
    private var model: String = "models/gemini-2.5-flash-lite"
    private var voice: String = "Aoede"
    private var systemInstruction: String = ""
    private var tools: JSONArray = JSONArray()

    fun setCallback(cb: Callback) {
        this.callback = cb
    }

    /**
     * Connect to Gemini Live with the given session configuration.
     */
    fun connect(config: JSONObject): Boolean {
        if (isRunning.get()) {
            Log.w(TAG, "Already connected")
            return true
        }

        apiKey = config.optString("api_key", "")
        model = config.optString("model", "models/gemini-2.5-flash-lite")
        voice = config.optString("voice", "Aoede")
        systemInstruction = config.optString("system_instruction", "")
        tools = config.optJSONArray("tools") ?: JSONArray()

        if (apiKey.isEmpty()) {
            postError("No API key provided", false)
            return false
        }

        isRunning.set(true)
        postState("connecting")

        executor.execute {
            try {
                connectWebSocket()
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                postError("Connection failed: ${e.message}", true)
                isRunning.set(false)
            }
        }

        return true
    }

    /**
     * Establish WebSocket connection to Gemini Live.
     */
    private fun connectWebSocket() {
        val urlStr = "$WS_URL?key=$apiKey"
        Log.i(TAG, "Connecting to Gemini Live WebSocket")

        try {
            val url = URL(urlStr)
            wsConnection = url.openConnection().apply {
                setRequestProperty("Upgrade", "websocket")
                setRequestProperty("Connection", "Upgrade")
                connectTimeout = 10000
                readTimeout = 60000
                (this as HttpsURLConnection).doOutput = true
                doInput = true
            }

            // Send WebSocket upgrade request
            val conn = wsConnection as HttpsURLConnection
            conn.connect()

            wsOutputStream = conn.outputStream
            wsInputStream = conn.inputStream

            Log.i(TAG, "WebSocket connected, HTTP ${conn.responseCode}")

            // Send initial configuration
            sendSetupMessage()

            // Start receiving messages
            startReceiving()

            // Start audio capture
            startAudioCapture()

            mainHandler.post {
                callback?.onConnected()
            }
            postState("connected")

        } catch (e: Exception) {
            Log.e(TAG, "WebSocket connection failed", e)
            postError("WebSocket connection failed: ${e.message}", true)
            isRunning.set(false)
        }
    }

    /**
     * Send the setup/configuration message to Gemini Live.
     */
    private fun sendSetupMessage() {
        val setup = JSONObject().apply {
            put("setup", JSONObject().apply {
                put("model", model)
                put("generationConfig", JSONObject().apply {
                    put("responseModalities", JSONArray().apply {
                        put("AUDIO")
                        put("TEXT")
                    })
                    put("speechConfig", JSONObject().apply {
                        put("voiceConfig", JSONObject().apply {
                            put("prebuiltVoiceConfig", JSONObject().apply {
                                put("voiceName", voice)
                            })
                        })
                    })
                })
                if (systemInstruction.isNotEmpty()) {
                    put("systemInstruction", JSONObject().apply {
                        put("parts", JSONArray().apply {
                            put(JSONObject().apply {
                                put("text", systemInstruction)
                            })
                        })
                    })
                }
                if (tools.length() > 0) {
                    put("tools", tools)
                }
            })
        }

        sendWebSocketMessage(setup.toString())
        Log.i(TAG, "Setup message sent")
    }

    /**
     * Send a text message to Gemini Live.
     */
    fun sendText(text: String) {
        if (!isRunning.get()) return

        val message = JSONObject().apply {
            put("clientContent", JSONObject().apply {
                put("turns", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "user")
                        put("parts", JSONArray().apply {
                            put(JSONObject().apply {
                                put("text", text)
                            })
                        })
                    })
                })
                put("turnComplete", true)
            })
        }

        sendWebSocketMessage(message.toString())
        Log.i(TAG, "Text sent: $text")
    }

    /**
     * Send audio data to Gemini Live.
     */
    fun sendAudio(audioData: ByteArray) {
        if (!isRunning.get()) return

        val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)
        val message = JSONObject().apply {
            put("realtimeInput", JSONObject().apply {
                put("mediaChunks", JSONArray().apply {
                    put(JSONObject().apply {
                        put("mimeType", "audio/pcm;rate=16000")
                        put("data", base64Audio)
                    })
                })
            })
        }

        sendWebSocketMessage(message.toString())
    }

    /**
     * Send a function call response back to Gemini.
     */
    fun sendFunctionResponse(callId: String, response: JSONObject) {
        if (!isRunning.get()) return

        val message = JSONObject().apply {
            put("toolResponse", JSONObject().apply {
                put("functionResponses", JSONArray().apply {
                    put(JSONObject().apply {
                        put("id", callId)
                        put("response", response)
                    })
                })
            })
        }

        sendWebSocketMessage(message.toString())
        Log.i(TAG, "Function response sent for call $callId")
    }

    /**
     * Start capturing audio from the microphone.
     */
    private fun startAudioCapture() {
        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            postError("Failed to get audio buffer size", false)
            return
        }

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                postError("AudioRecord failed to initialize", false)
                return
            }

            audioRecord?.startRecording()
            isRecording.set(true)

            // Initialize AudioTrack for playback
            val trackBufferSize = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AUDIO_FORMAT
            )
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .setEncoding(AUDIO_FORMAT)
                        .build()
                )
                .setBufferSizeInBytes(trackBufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            audioTrack?.play()

            recordingThread = Thread {
                val buffer = ShortArray(FRAME_SIZE)
                while (isRecording.get() && isRunning.get()) {
                    val read = audioRecord?.read(buffer, 0, FRAME_SIZE) ?: 0
                    if (read > 0) {
                        // Convert short samples to byte array (PCM 16-bit little-endian)
                        val byteBuffer = ByteBuffer.allocate(read * 2)
                            .order(ByteOrder.LITTLE_ENDIAN)
                        for (i in 0 until read) {
                            byteBuffer.putShort(buffer[i])
                        }
                        sendAudio(byteBuffer.array())
                    }
                }
            }.apply {
                name = "GeminiLive-AudioCapture"
                start()
            }

            Log.i(TAG, "Audio capture started")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start audio capture", e)
            postError("Microphone access failed: ${e.message}", false)
        }
    }

    /**
     * Stop audio capture.
     */
    private fun stopAudioCapture() {
        isRecording.set(false)
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null

            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null

            recordingThread?.join(1000)
            recordingThread = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio capture", e)
        }
    }

    /**
     * Start receiving messages from Gemini Live WebSocket.
     */
    private fun startReceiving() {
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(wsInputStream))
                while (isRunning.get()) {
                    val message = reader.readLine() ?: break
                    if (message.isNotEmpty()) {
                        handleServerMessage(message)
                    }
                }
            } catch (e: Exception) {
                if (isRunning.get()) {
                    Log.e(TAG, "Receive error", e)
                    postError("Connection lost: ${e.message}", true)
                    isRunning.set(false)
                }
            }
        }.apply {
            name = "GeminiLive-Receiver"
            start()
        }
    }

    /**
     * Handle a message from the Gemini Live server.
     */
    private fun handleServerMessage(raw: String) {
        try {
            val json = JSONObject(raw)

            // Setup complete
            if (json.has("setupComplete")) {
                Log.i(TAG, "Setup complete — session active")
                postState("live")
                return
            }

            // Server content (text or audio response)
            if (json.has("serverContent")) {
                val content = json.getJSONObject("serverContent")
                val modelTurn = content.optJSONObject("modelTurn")

                if (modelTurn != null) {
                    val parts = modelTurn.optJSONArray("parts")
                    if (parts != null) {
                        for (i in 0 until parts.length()) {
                            val part = parts.getJSONObject(i)
                            if (part.has("text")) {
                                val text = part.getString("text")
                                Log.i(TAG, "Model text: $text")
                                mainHandler.post {
                                    callback?.onResponse(text)
                                }
                            }
                            if (part.has("inlineData")) {
                                val audioData = Base64.decode(
                                    part.getJSONObject("inlineData").getString("data"),
                                    Base64.NO_WRAP
                                )
                                playAudio(audioData)
                            }
                        }
                    }
                }

                // Check if turn is complete
                if (content.optBoolean("turnComplete", false)) {
                    Log.d(TAG, "Turn complete")
                }
                return
            }

            // Tool call
            if (json.has("toolCall")) {
                val toolCall = json.getJSONObject("toolCall")
                val functionCalls = toolCall.optJSONArray("functionCalls")
                if (functionCalls != null) {
                    for (i in 0 until functionCalls.length()) {
                        val fc = functionCalls.getJSONObject(i)
                        val name = fc.optString("name", "")
                        val args = fc.optJSONObject("args") ?: JSONObject()
                        val callId = fc.optString("id", "")
                        Log.i(TAG, "Function call: $name($args)")
                        mainHandler.post {
                            callback?.onFunctionCall(name, args)
                        }
                    }
                }
                return
            }

            // Tool call cancellation
            if (json.has("toolCallCancellation")) {
                Log.i(TAG, "Tool call cancelled")
                return
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse server message: $raw", e)
        }
    }

    /**
     * Play audio data through AudioTrack.
     */
    private fun playAudio(audioData: ByteArray) {
        try {
            audioTrack?.write(audioData, 0, audioData.size)
            mainHandler.post {
                callback?.onAudioOutput(audioData)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio", e)
        }
    }

    /**
     * Send a raw WebSocket text frame.
     */
    private fun sendWebSocketMessage(message: String) {
        try {
            val output = wsOutputStream ?: return
            // WebSocket text frame: 0x81 (FIN + text), then length, then payload
            val payload = message.toByteArray(Charsets.UTF_8)
            output.write(0x81) // FIN + opcode=text

            if (payload.size < 126) {
                output.write(payload.size)
            } else if (payload.size < 65536) {
                output.write(126)
                output.write((payload.size shr 8) and 0xFF)
                output.write(payload.size and 0xFF)
            } else {
                output.write(127)
                for (i in 7 downTo 0) {
                    output.write((payload.size shr (i * 8)) and 0xFF)
                }
            }

            output.write(payload)
            output.flush()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send WebSocket message", e)
        }
    }

    /**
     * Disconnect from Gemini Live and clean up.
     */
    fun disconnect() {
        if (!isRunning.compareAndSet(true, false)) return

        Log.i(TAG, "Disconnecting from Gemini Live")
        postState("disconnecting")

        stopAudioCapture()

        try {
            wsOutputStream?.close()
            wsInputStream?.close()
            (wsConnection as? HttpURLConnection)?.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing connection", e)
        }

        wsOutputStream = null
        wsInputStream = null
        wsConnection = null

        mainHandler.post {
            callback?.onDisconnected("Manual disconnect")
        }
    }

    fun isActive(): Boolean = isRunning.get()

    private fun postError(message: String, recoverable: Boolean) {
        Log.e(TAG, "Error: $message (recoverable=$recoverable)")
        mainHandler.post {
            callback?.onError(message, recoverable)
        }
    }

    private fun postState(state: String) {
        mainHandler.post {
            callback?.onStateChange(state)
        }
    }
}
