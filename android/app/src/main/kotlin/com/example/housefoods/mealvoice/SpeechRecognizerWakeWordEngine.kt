package com.example.housefoods.mealvoice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.util.Locale

/**
 * Wake-word engine using Android's built-in SpeechRecognizer.
 * Detects "Hi MEAL" from continuous speech recognition.
 */
class SpeechRecognizerWakeWordEngine : WakeWordEngine {
    companion object {
        private const val TAG = "MEAL_SpeechRec"
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

            val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }

            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.i(TAG, "Ready for speech")
                }

                override fun onBeginningOfSpeech() {
                    Log.d(TAG, "Speech started")
                }

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d(TAG, "Speech ended")
                    if (isRunning) restartListening()
                }

                override fun onError(error: Int) {
                    Log.w(TAG, "Recognition error: $error")
                    if (isRunning && error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                        restartListening()
                    }
                }

                override fun onResults(results: Bundle?) {
                    processResults(results)
                    if (isRunning) restartListening()
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    processResults(partialResults)
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            speechRecognizer?.startListening(recognizerIntent)
            isRunning = true
            Log.i(TAG, "Wake-word detection started")
            onEventCallback?.onEvent("log", "Listening for 'Hi MEAL'")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start", e)
            onEventCallback?.onEvent("error", "Failed to start: ${e.message}")
            return false
        }
    }

    private fun processResults(results: Bundle?) {
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

    private fun restartListening() {
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart", e)
        }
    }

    override fun stop() {
        isRunning = false
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
