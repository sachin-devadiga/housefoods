package com.example.housefoods.mealvoice

import android.content.Context

/**
 * Abstract wake-word engine interface.
 */
interface WakeWordEngine {
    fun interface OnWakeWordDetected {
        fun onDetected()
    }

    fun interface OnEngineEvent {
        fun onEvent(type: String, data: Any?)
    }

    fun initialize(context: Context, onDetected: OnWakeWordDetected, onEvent: OnEngineEvent)
    fun start(): Boolean
    fun stop()
    fun release()
    fun isListening(): Boolean
    fun getEngineName(): String
}
