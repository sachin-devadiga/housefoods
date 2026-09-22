package com.example.housefoods

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlarmNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mealin/alarm_channel")
            .setMethodCallHandler { call, result ->
                if (call.method == "createAlarmChannel") {
                    createAlarmNotificationChannel()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun createAlarmNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "mealin_order_alarm"
            val nm = getSystemService(NotificationManager::class.java)
            // Delete first: channel settings (incl. sound) are immutable once
            // created, so this forces the fixed sound URI onto existing installs.
            try {
                nm.deleteNotificationChannel(channelId)
            } catch (_: Exception) {
            }
            val channelName = "Order Alarm"
            val channelDesc = "Loud alarm for new orders and deliveries"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDesc
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // NOTE: raw resource URIs must NOT include the file extension.
            val alarmUri = Uri.parse("android.resource://${packageName}/raw/alarm")
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            channel.setSound(alarmUri, audioAttributes)

            nm.createNotificationChannel(channel)
            Log.i("MEAL_Main", "Alarm notification channel created")
        }
    }
}
