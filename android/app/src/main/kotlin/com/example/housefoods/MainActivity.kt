package com.example.housefoods

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Do NOT start voice service here — it starts the native SpeechRecognizer
        // which plays an Android notification sound on every listen cycle.
        // The service is started by Flutter via MethodChannel when needed.
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

    private fun attachVoiceBridge(flutterEngine: FlutterEngine) {
        // Delay slightly to ensure service is created
        Handler(Looper.getMainLooper()).postDelayed({
            val service = MealVoiceService.getInstance()
            if (service != null && !bridgeAttached) {
                voiceBridge = MealVoiceBridge(flutterEngine, service)
                voiceBridge?.attach()
                bridgeAttached = true
                // Service already started from onCreate()
            } else {
                // Retry once more
                Handler(Looper.getMainLooper()).postDelayed({
                    val service2 = MealVoiceService.getInstance()
                    if (service2 != null && !bridgeAttached) {
                        voiceBridge = MealVoiceBridge(flutterEngine, service2)
                voiceBridge?.attach()
                        bridgeAttached = true
                    }
                }, 500)
            }
        }, 300)
    }

    override fun onDestroy() {
        voiceBridge?.detach()
        voiceBridge = null
        bridgeAttached = false
        super.onDestroy()
    }
}
