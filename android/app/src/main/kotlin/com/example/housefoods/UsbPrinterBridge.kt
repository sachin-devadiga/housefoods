package com.example.housefoods

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * USB thermal bill printer bridge (OTG cable).
 *
 * Channel: com.mealin/usb_printer
 * - listPrinters -> [{name, vid, pid, deviceId}]
 * - printBytes {vid, pid, bytes} -> {ok, error?}
 *
 * Opens the device, claims its first interface, writes ESC/POS bytes to the
 * first bulk-OUT endpoint, then releases everything. Runtime USB permission
 * is requested on the calling thread with a 10s timeout.
 */
class UsbPrinterBridge(private val context: Context) {
    companion object {
        private const val TAG = "MEAL_UsbPrinter"
        private const val ACTION_USB_PERMISSION = "com.mealin.USB_PERMISSION"
    }

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mealin/usb_printer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listPrinters" -> {
                        try {
                            result.success(listPrinters())
                        } catch (e: Exception) {
                            Log.e(TAG, "list failed", e)
                            result.error("LIST_FAILED", e.message, null)
                        }
                    }
                    "printBytes" -> {
                        Thread {
                            try {
                                val vid = (call.argument<Int>("vid") ?: -1)
                                val pid = (call.argument<Int>("pid") ?: -1)
                                val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                                val out = printBytes(vid, pid, bytes)
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.success(out)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "print failed", e)
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    result.success(mapOf("ok" to false, "error" to (e.message ?: "print failed")))
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun listPrinters(): List<Map<String, Any?>> {
        val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        return manager.deviceList.values.map { d ->
            mapOf<String, Any?>(
                "name" to (d.productName ?: d.deviceName),
                "deviceName" to d.deviceName,
                "vid" to d.vendorId,
                "pid" to d.productId,
                "deviceId" to d.deviceId,
            )
        }
    }

    private fun printBytes(vid: Int, pid: Int, bytes: ByteArray): Map<String, Any?> {
        if (bytes.isEmpty) return mapOf("ok" to false, "error" to "empty bill")
        val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        val device: UsbDevice = manager.deviceList.values.firstOrNull {
            it.vendorId == vid && it.productId == pid
        } ?: return mapOf("ok" to false, "error" to "printer not found — replug the OTG cable")

        if (!manager.hasPermission(device)) {
            if (!requestPermissionBlocking(manager, device)) {
                return mapOf("ok" to false, "error" to "USB permission denied")
            }
        }

        val connection = manager.openDevice(device)
            ?: return mapOf("ok" to false, "error" to "could not open USB device")
        try {
            var claimed: android.hardware.usb.UsbInterface? = null
            var outEndpoint: android.hardware.usb.UsbEndpoint? = null
            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                for (j in 0 until intf.endpointCount) {
                    val ep = intf.getEndpoint(j)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        ep.direction == UsbConstants.USB_DIR_OUT
                    ) {
                        claimed = intf
                        outEndpoint = ep
                        break
                    }
                }
                if (outEndpoint != null) break
            }
            if (claimed == null || outEndpoint == null) {
                return mapOf("ok" to false, "error" to "no bulk-OUT endpoint (not a printer?)")
            }
            if (!connection.claimInterface(claimed, true)) {
                return mapOf("ok" to false, "error" to "could not claim USB interface")
            }
            try {
                var offset = 0
                val chunk = 512
                while (offset < bytes.size) {
                    val len = minOf(chunk, bytes.size - offset)
                    val sent = connection.bulkTransfer(
                        outEndpoint,
                        bytes.copyOfRange(offset, offset + len),
                        len,
                        5000,
                    )
                    if (sent < 0) {
                        return mapOf("ok" to false, "error" to "USB write failed at byte $offset")
                    }
                    offset += sent
                }
            } finally {
                try {
                    connection.releaseInterface(claimed)
                } catch (_: Exception) {
                }
            }
            return mapOf("ok" to true)
        } finally {
            try {
                connection.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun requestPermissionBlocking(manager: UsbManager, device: UsbDevice): Boolean {
        val latch = CountDownLatch(1)
        var granted = false
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == ACTION_USB_PERMISSION) {
                    granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    latch.countDown()
                }
            }
        }
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val pi = PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), flags)
            manager.requestPermission(device, pi)
            latch.await(10, TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.e(TAG, "permission wait failed", e)
        } finally {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
        }
        return granted
    }
}
