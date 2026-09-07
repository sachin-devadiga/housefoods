package com.example.housefoods

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.housefoods.mealvoice.MealVoiceBridge
import com.example.housefoods.mealvoice.MealVoiceService
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mealin.app/install"
    private var voiceBridge: MealVoiceBridge? = null
    private var bridgeAttached = false
    private var pendingWakeWordIntent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Check if opened from wake word notification
        pendingWakeWordIntent = intent.getBooleanExtra("meal_voice_wake_word", false)
        if (pendingWakeWordIntent) {
            MealVoiceService.clearPendingWakeWord(this)
        }
        // Always create service without starting engine
        // Engine starts when Flutter calls startListening via MethodChannel
        startVoiceService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
                        } else {
                            Uri.fromFile(file)
                        }
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_PATH", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Attach MEAL Voice Bridge after service is running
        attachVoiceBridge(flutterEngine)
    }

    private fun startVoiceService() {
        val serviceIntent = Intent(this, MealVoiceService::class.java).apply {
            action = "ACTION_CREATE_ONLY"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun startVoiceServiceWithEngine() {
        val serviceIntent = Intent(this, MealVoiceService::class.java).apply {
            action = "ACTION_START"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun attachVoiceBridge(flutterEngine: FlutterEngine) {
        // Delay slightly to ensure service is created
        Handler(Looper.getMainLooper()).postDelayed({
            val service = MealVoiceService.getInstance()
            if (service != null && !bridgeAttached) {
                voiceBridge = MealVoiceBridge(flutterEngine, service)
                voiceBridge?.attach()
                bridgeAttached = true
                checkPendingWakeWord(flutterEngine)
            } else {
                // Retry once more
                Handler(Looper.getMainLooper()).postDelayed({
                    val service2 = MealVoiceService.getInstance()
                    if (service2 != null && !bridgeAttached) {
                        voiceBridge = MealVoiceBridge(flutterEngine, service2)
                        voiceBridge?.attach()
                        bridgeAttached = true
                        checkPendingWakeWord(flutterEngine)
                    }
                }, 500)
            }
        }, 300)
    }

    private fun checkPendingWakeWord(flutterEngine: FlutterEngine) {
        // Check if there's a pending wake word from when the app was killed
        if (pendingWakeWordIntent || MealVoiceService.hasPendingWakeWord(this)) {
            MealVoiceService.clearPendingWakeWord(this)
            pendingWakeWordIntent = false
            // Send the wake word event to Flutter via EventChannel
            Handler(Looper.getMainLooper()).postDelayed({
                voiceBridge?.sendEvent("wakeWordDetected", System.currentTimeMillis().toString())
                Log.i("MEAL_Main", "Sent pending wake word event to Flutter")
            }, 500)
        }
    }

    override fun onDestroy() {
        voiceBridge?.detach()
        voiceBridge = null
        bridgeAttached = false
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("meal_voice_wake_word", false)) {
            MealVoiceService.clearPendingWakeWord(this)
            // Ensure engine is running
            val service = MealVoiceService.getInstance()
            if (service != null && !service.isRunning) {
                startVoiceServiceWithEngine()
            }
            // Send wake word event to Flutter immediately
            Handler(Looper.getMainLooper()).postDelayed({
                voiceBridge?.sendEvent("wakeWordDetected", System.currentTimeMillis().toString())
                Log.i("MEAL_Main", "Sent wake word event via onNewIntent")
            }, 500)
        }
    }
}
