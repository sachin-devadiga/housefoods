import 'package:flutter/services.dart';

/// Dart wrapper for the native USB thermal printer bridge
/// (MainActivity → UsbPrinterBridge, channel com.mealin/usb_printer).
class UsbPrinterDevice {
  final String name;
  final String deviceName;
  final int vid;
  final int pid;
  final int deviceId;

  UsbPrinterDevice({
    required this.name,
    required this.deviceName,
    required this.vid,
    required this.pid,
    required this.deviceId,
  });

  factory UsbPrinterDevice.fromMap(Map<dynamic, dynamic> map) {
    return UsbPrinterDevice(
      name: (map['name'] ?? map['deviceName'] ?? 'USB Printer').toString(),
      deviceName: (map['deviceName'] ?? '').toString(),
      vid: (map['vid'] as int?) ?? -1,
      pid: (map['pid'] as int?) ?? -1,
      deviceId: (map['deviceId'] as int?) ?? -1,
    );
  }
}

class UsbPrinter {
  static const _channel = MethodChannel('com.mealin/usb_printer');

  static Future<List<UsbPrinterDevice>> listDevices() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('listPrinters');
      if (result == null) return [];
      return result
          .whereType<Map<dynamic, dynamic>>()
          .map(UsbPrinterDevice.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sends raw ESC/POS [bytes] to the USB printer. Returns (ok, error).
  static Future<({bool ok, String? error})> printBytes({
    required int vid,
    required int pid,
    required List<int> bytes,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'printBytes',
        {'vid': vid, 'pid': pid, 'bytes': Uint8List.fromList(bytes)},
      );
      final ok = result?['ok'] == true;
      final error = result?['error']?.toString();
      return (ok: ok, error: ok ? null : error);
    } catch (e) {
      return (ok: false, error: e.toString());
    }
  }
}
