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
 * Two-phase voice engine:
 *   Phase 1: Continuous listening for "Hi MEAL"
 *   Phase 2: After wake word, captures user's command as transcription
 *
 * Fixes: #27 (isCapturingCommand reset on restart), #28 (finalizeCommand called once),
 *        #29 (delayed restart after stop).
 */
class SpeechRecognizerWakeWordEngine : WakeWordEngine {
    companion object {
        private const val TAG = "MEAL_SpeechRec"
        private const val COMMAND_LISTEN_TIMEOUT_MS = 10000L
        private const val RESTART_DELAY_MS = 300L

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

    // Phase 2: Command capture state
    private var isCapturingCommand = false
    private var commandFinalized = false // FIX #28: prevent double finalize
    private var commandResults = StringBuilder()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var commandTimeoutRunnable: Runnable? = null

    override fun initialize(context: Context, onDetected: WakeWordEngine.OnWakeWordDetected, onEvent: WakeWordEngine.OnEngineEvent) {
        this.context = context
        this.onDetectedCallback = onDetected
        this.onEventCallback = onEvent
        isInitialized = true
        Log.i(TAG, "Engine initialized")
        onEventCallback?.onEvent("log", "SpeechRecognizer engine initialized")
    }

    override fun start(): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "Engine not initialized")
            onEventCallback?.onEvent("error", "Voice engine not initialized")
            return false
        }

        // Check if speech recognition is available
        val recognitionAvailable = try {
            SpeechRecognizer.isRecognitionAvailable(context!!)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking recognition availability", e)
            false
        }

        if (!recognitionAvailable) {
            val msg = "Speech recognition not available on this device. " +
                "Please ensure Google app or a speech recognition service is installed."
            Log.e(TAG, msg)
            onEventCallback?.onEvent("error", msg)
            return false
        }

        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context!!)

            speechRecognizer?.setRecognitionListener(createWakeWordListener())
            speechRecognizer?.startListening(createRecognitionIntent())
            isRunning = true
            isCapturingCommand = false
            commandFinalized = false
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
     * FIX #30: Guard against double-startCommandCapture.
     * Only start if not already capturing.
     */
    fun startCommandCapture(): Boolean {
        if (!isRunning || speechRecognizer == null) {
            Log.e(TAG, "Cannot start command capture — not running")
            return false
        }

        if (isCapturingCommand) {
            Log.i(TAG, "Already capturing command — skipping")
            return true
        }

        isCapturingCommand = true
        commandFinalized = false // FIX #28: reset finalize flag
        commandResults.clear()

        try {
            speechRecognizer?.stopListening()

            // FIX #29: Small delay before restarting to avoid device race conditions
            mainHandler.postDelayed({
                try {
                    speechRecognizer?.setRecognitionListener(createCommandCaptureListener())
                    speechRecognizer?.startListening(createRecognitionIntent())
                    scheduleCommandTimeout()
                    Log.i(TAG, "Command capture started")
                    onEventCallback?.onEvent("log", "Listening for command...")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start command capture", e)
                    onEventCallback?.onEvent("error", "Command capture failed: ${e.message}")
                    isCapturingCommand = false
                }
            }, RESTART_DELAY_MS)

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start command capture", e)
            onEventCallback?.onEvent("error", "Command capture failed: ${e.message}")
            isCapturingCommand = false
            return false
        }
    }

    /**
     * Stop command capture and return to wake-word mode.
     */
    fun stopCommandCapture() {
        isCapturingCommand = false
        commandFinalized = false
        cancelCommandTimeout()
        commandResults.clear()
    }

    /**
     * FIX #31: Actually restart wake-word listening by resetting the listener.
     */
    fun restartWakeWordListening() {
        Log.i(TAG, "Restarting wake-word listening")
        isCapturingCommand = false
        commandFinalized = false
        cancelCommandTimeout()
        commandResults.clear()

        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.setRecognitionListener(createWakeWordListener())
            speechRecognizer?.startListening(createRecognitionIntent())
            Log.i(TAG, "Wake-word listening restarted")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart wake-word listening", e)
        }
    }

    private fun createRecognitionIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
    }

    // ─── Phase 1: Wake Word Listener ───

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
                // Only restart if still in wake-word mode
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
                // FIX #27: Only process if NOT in command capture mode
                if (isRunning && !isCapturingCommand) {
                    processWakeWordResults(results)
                    if (isRunning && !isCapturingCommand) {
                        restartListening()
                    }
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (isRunning && !isCapturingCommand) {
                    processWakeWordResults(partialResults)
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

    // ─── Phase 2: Command Capture Listener ───

    private fun createCommandCaptureListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.i(TAG, "Ready for command")
                onEventCallback?.onEvent("stateChanged", "4") // LISTENING_TO_USER
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Command speech started")
                onEventCallback?.onEvent("log", "Speech detected")
                cancelCommandTimeout() // User started speaking, cancel timeout
            }

            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                Log.d(TAG, "Command speech ended")
                // FIX #28: Only finalize once
                if (!commandFinalized) {
                    finalizeCommand()
                }
            }

            override fun onError(error: Int) {
                Log.w(TAG, "Command recognition error: $error")
                // FIX #28: Only finalize once
                if (commandFinalized) return

                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        if (commandResults.isEmpty()) {
                            onEventCallback?.onEvent("commandTimeout", "No speech detected")
                            isCapturingCommand = false
                        } else {
                            finalizeCommand()
                        }
                    }
                    SpeechRecognizer.ERROR_CLIENT -> {
                        // Recognition was stopped externally — if we have results, use them
                        if (commandResults.isNotEmpty()) {
                            finalizeCommand()
                        } else {
                            isCapturingCommand = false
                        }
                    }
                    else -> {
                        if (error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                            onEventCallback?.onEvent("error", "Speech error: $error")
                            isCapturingCommand = false
                        }
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                // FIX #28: Only finalize once
                if (commandFinalized) return

                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    commandResults.clear()
                    commandResults.append(matches[0])
                }
                finalizeCommand()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (commandFinalized) return

                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    commandResults.clear()
                    commandResults.append(matches[0])
                    onEventCallback?.onEvent("speechPartial", matches[0])
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    /**
     * FIX #28: Use commandFinalized flag to prevent double finalize.
     */
    private fun finalizeCommand() {
        if (commandFinalized) return
        commandFinalized = true

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
            if (isCapturingCommand && !commandFinalized) {
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

    /**
     * FIX #27: resetListening resets isCapturingCommand before restarting.
     */
    private fun restartListening() {
        try {
            speechRecognizer?.stopListening()
            mainHandler.postDelayed({
                try {
                    isCapturingCommand = false // FIX #27: reset before restart
                    commandFinalized = false
                    speechRecognizer?.setRecognitionListener(createWakeWordListener())
                    speechRecognizer?.startListening(createRecognitionIntent())
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restart", e)
                }
            }, RESTART_DELAY_MS)
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting", e)
        }
    }

    override fun stop() {
        isRunning = false
        isCapturingCommand = false
        commandFinalized = false
        cancelCommandTimeout()
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping", e)
        }
        Log.i(TAG, "Engine stopped")
    }

    override fun release() {
        stop()
        isInitialized = false
        context = null
    }

    override fun isListening(): Boolean = isRunning

    override fun getEngineName(): String = "Android SpeechRecognizer"
}
