package com.example.housefoods.mealvoice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.util.Locale

/**
 * Wake-word engine using Android's built-in SpeechRecognizer.
 * Two-phase operation:
 *   Phase 1: Continuous listening for "Hi MEAL"
 *   Phase 2: After wake word, captures user's command as transcription
 */
class SpeechRecognizerWakeWordEngine : WakeWordEngine {
    companion object {
        private const val TAG = "MEAL_SpeechRec"
        private const val COMMAND_LISTEN_TIMEOUT_MS = 10000L // 10 seconds

        private val WAKE_PHRASES = listOf(
            "hi meal", "hey meal", "hi meil", "hey meil",
            "hi mel", "hey mel", "hi mealin", "hey mealin",
            "hello meal", "ok meal"
        )
    }

    private var context: Context? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var onDetectedCallback: WakeWordEngine.OnWakeWordDetected? = null
    private var onEventCallback: WakeWordEngine.OnEngineEvent? = null
    private var isRunning = false
    private var isInitialized = false

    // Phase 2: Command capture
    private var isCapturingCommand = false
    private var commandResults = StringBuilder()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var commandTimeoutRunnable: Runnable? = null

    override fun initialize(context: Context, onDetected: WakeWordEngine.OnWakeWordDetected, onEvent: WakeWordEngine.OnEngineEvent) {
        this.context = context
        this.onDetectedCallback = onDetected
        this.onEventCallback = onEvent
        isInitialized = true
        Log.i(TAG, "SpeechRecognizer engine initialized")
        onEventCallback?.onEvent("log", "SpeechRecognizer engine initialized")
    }

    override fun start(): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "Engine not initialized")
            return false
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context!!)) {
            Log.e(TAG, "Speech recognition not available")
            onEventCallback?.onEvent("error", "Speech recognition not available")
            return false
        }

        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context!!)

            val recognizerIntent = createRecognitionIntent()

            speechRecognizer?.setRecognitionListener(createWakeWordListener())
            speechRecognizer?.startListening(recognizerIntent)
            isRunning = true
            isCapturingCommand = false
            Log.i(TAG, "Wake-word detection started")
            onEventCallback?.onEvent("log", "Listening for 'Hi MEAL'")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start", e)
            onEventCallback?.onEvent("error", "Failed to start: ${e.message}")
            return false
        }
    }

    /**
     * Switch from wake-word listening to command capture mode.
     * Called after "Hi MEAL" is detected.
     */
    fun startCommandCapture(): Boolean {
        if (!isRunning || speechRecognizer == null) {
            Log.e(TAG, "Cannot start command capture — not running")
            return false
        }

        isCapturingCommand = true
        commandResults.clear()

        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.setRecognitionListener(createCommandCaptureListener())

            val intent = createRecognitionIntent().apply {
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            }
            speechRecognizer?.startListening(intent)

            // Set timeout for command capture
            scheduleCommandTimeout()

            Log.i(TAG, "Command capture started")
            onEventCallback?.onEvent("log", "Listening for command...")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start command capture", e)
            onEventCallback?.onEvent("error", "Command capture failed: ${e.message}")
            return false
        }
    }

    /**
     * Stop command capture and return to wake-word mode.
     */
    fun stopCommandCapture() {
        isCapturingCommand = false
        cancelCommandTimeout()
        commandResults.clear()
    }

    private fun createRecognitionIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
    }

    private fun createWakeWordListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.i(TAG, "Ready for speech (wake phase)")
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Speech started (wake phase)")
            }

            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                Log.d(TAG, "Speech ended (wake phase)")
                if (isRunning && !isCapturingCommand) {
                    restartListening()
                }
            }

            override fun onError(error: Int) {
                Log.w(TAG, "Recognition error: $error")
                if (isRunning && !isCapturingCommand && error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                    restartListening()
                }
            }

            override fun onResults(results: Bundle?) {
                if (!isCapturingCommand) {
                    processWakeWordResults(results)
                    if (isRunning && !isCapturingCommand) {
                        restartListening()
                    }
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (!isCapturingCommand) {
                    processWakeWordResults(partialResults)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun createCommandCaptureListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.i(TAG, "Ready for command")
                onEventCallback?.onEvent("stateChanged", "4") // LISTENING_TO_USER
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Command speech started")
                onEventCallback?.onEvent("log", "Speech detected")
            }

            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                Log.d(TAG, "Command speech ended")
                finalizeCommand()
            }

            override fun onError(error: Int) {
                Log.w(TAG, "Command recognition error: $error")
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        if (commandResults.isEmpty()) {
                            onEventCallback?.onEvent("commandTimeout", "No speech detected")
                        } else {
                            finalizeCommand()
                        }
                    }
                    else -> {
                        if (error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                            onEventCallback?.onEvent("error", "Speech error: $error")
                        }
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    commandResults.clear()
                    commandResults.append(matches[0])
                }
                finalizeCommand()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    commandResults.clear()
                    commandResults.append(matches[0])
                    // Send partial result to Flutter
                    onEventCallback?.onEvent("speechPartial", matches[0])
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun processWakeWordResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: return
        for (match in matches) {
            val lower = match.lowercase().trim()
            for (phrase in WAKE_PHRASES) {
                if (lower.contains(phrase)) {
                    Log.i(TAG, "WAKE WORD DETECTED: $match")
                    onDetectedCallback?.onDetected()
                    onEventCallback?.onEvent("log", "Wake word detected: $match")
                    return
                }
            }
        }
    }

    private fun finalizeCommand() {
        cancelCommandTimeout()

        if (commandResults.isNotEmpty()) {
            val transcription = commandResults.toString().trim()
            Log.i(TAG, "Command transcription: $transcription")
            onEventCallback?.onEvent("commandTranscription", transcription)
        } else {
            onEventCallback?.onEvent("commandTimeout", "No command received")
        }

        isCapturingCommand = false
        commandResults.clear()
    }

    private fun scheduleCommandTimeout() {
        cancelCommandTimeout()
        commandTimeoutRunnable = Runnable {
            if (isCapturingCommand) {
                Log.i(TAG, "Command timeout")
                if (commandResults.isNotEmpty()) {
                    finalizeCommand()
                } else {
                    onEventCallback?.onEvent("commandTimeout", "No speech detected after wake word")
                    isCapturingCommand = false
                }
            }
        }
        mainHandler.postDelayed(commandTimeoutRunnable!!, COMMAND_LISTEN_TIMEOUT_MS)
    }

    private fun cancelCommandTimeout() {
        commandTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        commandTimeoutRunnable = null
    }

    private fun restartListening() {
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.setRecognitionListener(createWakeWordListener())
            val intent = createRecognitionIntent()
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart", e)
        }
    }

    override fun stop() {
        isRunning = false
        isCapturingCommand = false
        cancelCommandTimeout()
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping", e)
        }
        Log.i(TAG, "Wake-word detection stopped")
    }

    override fun release() {
        stop()
        isInitialized = false
        context = null
    }

    override fun isListening(): Boolean = isRunning

    override fun getEngineName(): String = "Android SpeechRecognizer"
}
