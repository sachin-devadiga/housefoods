package com.example.housefoods

import android.content.Intent
import android.net.Uri
import android.os.Build
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(context, "${applicationContext.packageName}.fileprovider", file)
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

        // Wire up MEAL Voice Bridge
        val service = MealVoiceService.getInstance()
        if (service != null) {
            voiceBridge = MealVoiceBridge(flutterEngine, service)
            voiceBridge?.attach()
        } else {
            // Service not yet running — start it and attach bridge on next activity
            voiceBridge = null
        }
    }

    override fun onDestroy() {
        voiceBridge?.detach()
        voiceBridge = null
        super.onDestroy()
    }
}
