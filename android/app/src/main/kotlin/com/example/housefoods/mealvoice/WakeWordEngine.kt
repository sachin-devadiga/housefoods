package com.example.housefoods.mealvoice

import android.content.Context
import android.util.Log

/**
 * Abstract wake-word engine interface.
 * Implementations detect a custom wake word from microphone audio.
 */
interface WakeWordEngine {
    /** Callback when wake word is detected */
    fun interface OnWakeWordDetected {
        fun onDetected()
    }

    /** Callback for engine events */
    fun interface OnEngineEvent {
        fun onEvent(type: String, data: Any? = null)
    }

    /** Initialize the engine with context and callbacks */
    fun initialize(
        context: Context,
        onDetected: OnWakeWordDetected,
        onEvent: OnEngineEvent
    )

    /** Start listening for wake word */
    fun start(): Boolean

    /** Stop listening */
    fun stop()

    /** Release resources */
    fun release()

    /** Check if engine is currently listening */
    fun isListening(): Boolean

    /** Get engine name */
    fun getEngineName(): String
}

/**
 * Porcupine-based wake-word engine.
 * Uses Picovoice Porcupine for on-device wake-word detection.
 *
 * Requires:
 * - Picovoice API key (set in picovoice_config.properties or build config)
 * - Custom wake word "Hi MEAL" .ppn file in assets/
 *
 * To create "Hi MEAL" wake word:
 * 1. Go to https://console.picovoice.ai
 * 2. Create account (free tier)
 * 3. Go to Porcupine → Create Wake Word
 * 4. Type "Hi MEAL"
 * 5. Download .ppn file for Android
 * 6. Place in android/app/src/main/assets/hi_meal_android.ppn
 */
class PorcupineWakeWordEngine : WakeWordEngine {
    companion object {
        private const val TAG = "MEAL_Porcupine"
    }

    private var isInitialized = false
    private var isRunning = false
    private var onDetectedCallback: WakeWordEngine.OnWakeWordDetected? = null
    private var onEventCallback: WakeWordEngine.OnEngineEvent? = null

    override fun initialize(
        context: Context,
        onDetected: WakeWordEngine.OnWakeWordDetected,
        onEvent: WakeWordEngine.OnEngineEvent
    ) {
        this.onDetectedCallback = onDetected
        this.onEventCallback = onEvent
        isInitialized = true
        Log.i(TAG, "Porcupine engine initialized")
        onEventCallback?.onEvent("log", "Porcupine engine initialized")
    }

    override fun start(): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "Engine not initialized")
            return false
        }

        // TODO: Initialize actual Porcupine SDK
        // val porcupine = Porcupine.Builder()
        //     .setAccessKey(POICUVOCE_ACCESS_KEY)
        //     .setKeywordPath("hi_meal_android.ppn")
        //     .build(context)
        //
        // Then start audio capture loop:
        // while (isRunning) {
        //     val frame = audioRecord.read()
        //     val keywordIndex = porcupine.process(frame)
        //     if (keywordIndex >= 0) {
        //         onDetectedCallback?.onDetected()
        //     }
        // }

        isRunning = true
        Log.i(TAG, "Wake-word detection started (placeholder)")
        onEventCallback?.onEvent("log", "Wake-word detection started")
        return true
    }

    override fun stop() {
        isRunning = false
        Log.i(TAG, "Wake-word detection stopped")
        onEventCallback?.onEvent("log", "Wake-word detection stopped")
    }

    override fun release() {
        stop()
        isInitialized = false
        Log.i(TAG, "Porcupine engine released")
    }

    override fun isListening(): Boolean = isRunning

    override fun getEngineName(): String = "Porcupine"
}
