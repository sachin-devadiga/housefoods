package com.example.housefoods.mealvoice

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale

/**
 * Native voice processor — handles Gemini + TTS + API calls when Flutter is dead.
 * Runs in the :voice_service process.
 */
class VoiceNativeProcessor(private val context: Context) {

    companion object {
        private const val TAG = "MEAL_NativeProc"
        private const val BACKEND_URL = "https://housefoods.onrender.com"
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var onTtsComplete: (() -> Unit)? = null

    fun initialize(onReady: () -> Unit = {}) {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsReady = true
                tts?.language = Locale.US
                Log.i(TAG, "TTS initialized")
            } else {
                Log.e(TAG, "TTS init failed: $status")
            }
            onReady()
        }
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    /**
     * Call the Gemini backend proxy with conversation context.
     * Returns the raw text response from Gemini.
     */
    fun callGemini(
        prompt: String,
        authToken: String,
        systemPrompt: String = DEFAULT_SYSTEM_PROMPT,
        conversationHistory: List<Map<String, String>> = emptyList(),
        contextData: Map<String, Any> = emptyMap(),
    ): String? {
        try {
            val url = URL("$BACKEND_URL/api/auth/voice/gemini/")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $authToken")
                connectTimeout = 20000
                readTimeout = 20000
                doOutput = true
            }

            val body = JSONObject().apply {
                put("prompt", prompt)
                put("system_prompt", systemPrompt)
                put("model", "gemini-2.5-flash-lite")
                put("temperature", 0.7)
                put("max_output_tokens", 300)
                put("conversation_history", JSONArray().apply {
                    for (turn in conversationHistory) {
                        put(JSONObject().apply {
                            put("role", turn["role"] ?: "user")
                            put("content", turn["content"] ?: "")
                        })
                    }
                })
                put("context", JSONObject(contextData))
            }

            conn.outputStream.write(body.toString().toByteArray())
            conn.outputStream.flush()

            val responseCode = conn.responseCode
            Log.i(TAG, "Gemini HTTP $responseCode")

            if (responseCode == 200) {
                val response = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(response)
                return json.optString("text", null)
            } else {
                val error = conn.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
                Log.e(TAG, "Gemini error $responseCode: $error")
                return null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gemini call failed", e)
            return null
        }
    }

    /**
     * Parse Gemini's JSON response into response text + actions.
     */
    fun parseGeminiResponse(text: String): Pair<String, List<JSONObject>> {
        try {
            var cleaned = text.trim()
            if (cleaned.startsWith("```json")) cleaned = cleaned.substring(7)
            else if (cleaned.startsWith("```")) cleaned = cleaned.substring(3)
            if (cleaned.endsWith("```")) cleaned = cleaned.substring(0, cleaned.length - 3)
            cleaned = cleaned.trim()

            val json = JSONObject(cleaned)
            val response = json.optString("response", "")
            val actions = mutableListOf<JSONObject>()
            val actionsArray = json.optJSONArray("actions")
            if (actionsArray != null) {
                for (i in 0 until actionsArray.length()) {
                    actions.add(actionsArray.getJSONObject(i))
                }
            }
            return Pair(response, actions)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse Gemini response", e)
            return Pair(text, emptyList())
        }
    }

    /**
     * Search menu via backend API.
     */
    fun searchMenu(query: String, authToken: String): String? {
        try {
            val encodedQuery = URLEncoder.encode(query, "UTF-8")
            val url = URL("$BACKEND_URL/api/auth/kitchens/?search=$encodedQuery")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $authToken")
                connectTimeout = 15000
                readTimeout = 15000
            }

            if (conn.responseCode == 200) {
                return conn.inputStream.bufferedReader().readText()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Menu search failed", e)
        }
        return null
    }

    /**
     * Speak text via Android TTS.
     */
    fun speak(text: String, onDone: () -> Unit = {}) {
        if (!ttsReady || text.isEmpty()) {
            onDone()
            return
        }
        onTtsComplete = onDone
        val mainHandler = Handler(Looper.getMainLooper())
        tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) {
                mainHandler.post {
                    onTtsComplete?.invoke()
                    onTtsComplete = null
                }
            }
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    onTtsComplete?.invoke()
                    onTtsComplete = null
                }
            }
        })
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "meal_response")
    }

    /**
     * Get auth token from SharedPreferences (synced by Flutter).
     */
    fun getAuthToken(): String? {
        // Flutter SharedPreferences plugin uses "FlutterSharedPreferences" file with "flutter." prefix
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterToken = flutterPrefs.getString("flutter.auth_token", null)
        if (!flutterToken.isNullOrEmpty()) return flutterToken

        // Also try without prefix (if saved directly)
        val directToken = flutterPrefs.getString("auth_token", null)
        if (!directToken.isNullOrEmpty()) return directToken

        // Also check meal_voice_prefs (native-side backup)
        val voicePrefs = context.getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
        return voicePrefs.getString("auth_token", null)
    }

    /**
     * Get saved user name.
     */
    fun getUserName(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val name = flutterPrefs.getString("flutter.user_name", null)
        if (!name.isNullOrEmpty()) return name
        val voicePrefs = context.getSharedPreferences("meal_voice_prefs", Context.MODE_PRIVATE)
        return voicePrefs.getString("user_name", "") ?: ""
    }

    private val DEFAULT_SYSTEM_PROMPT = """
You are MEAL, the voice assistant for MEALIN food ordering app. You ONLY help with food ordering on MEALIN.
STRICT SCOPE: Only handle restaurants, menus, food, cart, orders, delivery, payment, coupons, MEALIN features.
If asked about anything else, respond: "I'm MEAL, your food ordering assistant. I can help you find restaurants, browse menus, and place orders on MEALIN. What would you like to eat?"
Be conversational, warm, helpful. Keep responses concise for voice (1-3 sentences).
Detect user's language and respond in the same language.
Respond with valid JSON only:
{"response": "Your reply", "actions": [{"type": "action_type", ...}]}
Actions: search_menu, add_to_cart, remove_from_cart, clear_cart, show_cart, place_order, none.
Never say "As an AI" — just be MEAL. Never invent prices. Always confirm before placing order.
"""
}
