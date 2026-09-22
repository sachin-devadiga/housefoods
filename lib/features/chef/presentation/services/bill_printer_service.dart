import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart';
import '../../../customer/domain/models/order_model.dart';

/// Bluetooth thermal bill printing for the resto app.
///
/// One-time setup (Profile → Bill Printer): pick a paired printer, test it.
/// Afterwards every order card can print its bill with one tap.
class BillPrinterService {
  static const _kMac = 'bill_printer_mac';
  static const _kName = 'bill_printer_name';
  static const _kPaper = 'bill_printer_paper_mm';

  static String? _lastError;
  static String? get lastError => _lastError;

  static Future<List<BluetoothInfo>> pairedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      _lastError = e.toString();
      return [];
    }
  }

  static Future<bool> connect(String mac) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  static Future<bool> get isConnected async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  static Future<void> savePrinter({required String mac, required String name, required int paperMm}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMac, mac);
    await prefs.setString(_kName, name);
    await prefs.setInt(_kPaper, paperMm);
  }

  static Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMac);
    await prefs.remove(_kName);
  }

  static Future<({String mac, String name, int paperMm})?> loadPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_kMac) ?? '';
    if (mac.isEmpty) return null;
    return (
      mac: mac,
      name: prefs.getString(_kName) ?? 'Printer',
      paperMm: prefs.getInt(_kPaper) ?? 80,
    );
  }

  static Future<bool> isConfigured() async => (await loadPrinter()) != null;

  // ── USB thermal printers (OTG cable) ──────────────────────────────

  static Future<List<UsbDevice>> usbDevices() async {
    try {
      return await UsbSerial.listDevices();
    } catch (e) {
      _lastError = e.toString();
      return [];
    }
  }

  /// Sends ESC/POS bill bytes to a USB printer. Returns true on success.
  static Future<bool> printUsbBill({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
    required UsbDevice device,
    int paperMm = 80,
  }) async {
    UsbPort? port;
    try {
      if (device.deviceId != null) {
        port = await UsbSerial.createFromDeviceId(device.deviceId);
      }
      port ??= (device.vid != null && device.pid != null)
          ? await UsbSerial.create(device.vid!, device.pid!)
          : null;
      if (port == null) {
        _lastError = 'Could not open USB device';
        return false;
      }
      final opened = await port.open();
      if (!opened) {
        _lastError = 'USB permission denied or device busy';
        try {
          await port.close();
        } catch (_) {}
        return false;
      }
      final bytes = await _buildBillBytes(
        order: order,
        kitchenName: kitchenName,
        kitchenAddress: kitchenAddress,
        paperMm: paperMm,
      );
      await port.write(Uint8List.fromList(bytes));
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        await port.close();
      } catch (_) {}
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[BillPrinter] USB print failed: $e');
      try {
        await port?.close();
      } catch (_) {}
      return false;
    }
  }

  // ── PDF bill (Zomato-style receipt) ───────────────────────────────
  // NOTE: PDFs use "Rs." because the built-in PDF font has no ₹ glyph.

  static Future<Uint8List> buildPdfBill({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
  }) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final shortId = order.id.length >= 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();
    final paidOnline = order.paymentId.isNotEmpty;

    double itemsTotal = 0;
    for (final item in order.items) {
      itemsTotal += item.priceAtOrder * item.quantity;
    }
    if (itemsTotal <= 0 && order.items.isNotEmpty) {
      itemsTotal = order.amount;
    }

    pw.Widget row(String left, String right, {bool bold = false, double size = 10}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
                child: pw.Text(left,
                    style: pw.TextStyle(
                        fontSize: size,
                        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
            pw.Text(right,
                style: pw.TextStyle(
                    fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
                child: pw.Text(kitchenName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
            if (kitchenAddress.isNotEmpty)
              pw.Center(child: pw.Text(kitchenAddress, style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            row('Order #$shortId', dateStr, size: 9),
            pw.Center(
                child: pw.Text(paidOnline ? 'ONLINE PAID' : 'CASH ON DELIVERY',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            pw.Divider(thickness: 1),
            ...order.items.map((item) {
              final qty = item.quantity;
              final rate = item.priceAtOrder > 0
                  ? item.priceAtOrder
                  : (order.items.isNotEmpty
                      ? itemsTotal / order.items.length / (qty == 0 ? 1 : qty)
                      : 0);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  row('$qty x ${item.menuItemName}', 'Rs.${(rate * qty).toStringAsFixed(0)}'),
                  if (item.specialInstructions.isNotEmpty)
                    pw.Text('  Note: ${item.specialInstructions}',
                        style: const pw.TextStyle(fontSize: 8)),
                ],
              );
            }),
            pw.Divider(thickness: 1),
            row('Item Total', 'Rs.${itemsTotal.toStringAsFixed(0)}'),
            row('Delivery', 'FREE'),
            if (order.tip > 0) row('Tip', 'Rs.${order.tip.toStringAsFixed(0)}'),
            pw.SizedBox(height: 4),
            row('TOTAL', 'Rs.${order.amount.toStringAsFixed(0)}', bold: true, size: 14),
            pw.Divider(thickness: 1),
            if (order.deliveryAddress.isNotEmpty) ...[
              pw.Text('Deliver to:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(order.deliveryAddress, style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 1),
            ],
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('Thank you! Visit again.',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Center(
                child: pw.Text('Powered by MEALIN', style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Opens the system print dialog (works with USB/WiFi printers via Android print service).
  static Future<bool> systemPrintBill({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
  }) async {
    try {
      final pdf = await buildPdfBill(
          order: order, kitchenName: kitchenName, kitchenAddress: kitchenAddress);
      return await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: 'MEALIN-Bill-${order.id}',
        format: PdfPageFormat.roll80,
      );
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Shares/saves the bill as a PDF file (WhatsApp, Drive, downloads…).
  static Future<bool> sharePdfBill({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
  }) async {
    try {
      final pdf = await buildPdfBill(
          order: order, kitchenName: kitchenName, kitchenAddress: kitchenAddress);
      return await Printing.sharePdf(
        bytes: pdf,
        filename: 'MEALIN-Bill-${order.id}.pdf',
      );
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  static Future<bool> testPrint() async {
    final saved = await loadPrinter();
    if (saved == null) {
      _lastError = 'No printer configured';
      return false;
    }
    try {
      if (!await isConnected) {
        final ok = await connect(saved.mac);
        if (!ok) {
          _lastError = 'Could not connect to ${saved.name}';
          return false;
        }
      }
      final profile = await CapabilityProfile.load();
      final paper = saved.paperMm == 58 ? PaperSize.mm58 : PaperSize.mm80;
      final gen = Generator(paper, profile);
      List<int> bytes = [];
      bytes += gen.text('MEALIN TEST PRINT',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      bytes += gen.text(saved.name, styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(1);
      bytes += gen.cut();
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) _lastError = 'Printer did not accept data';
      return ok;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[BillPrinter] test print failed: $e');
      return false;
    }
  }

  static Future<bool> printOrderBill({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
  }) async {
    final saved = await loadPrinter();
    if (saved == null) {
      _lastError = 'No printer configured';
      return false;
    }
    try {
      if (!await isConnected) {
        final ok = await connect(saved.mac);
        if (!ok) {
          _lastError = 'Could not connect to ${saved.name}. Is it on and paired?';
          return false;
        }
      }
      final bytes = await _buildBillBytes(
        order: order,
        kitchenName: kitchenName,
        kitchenAddress: kitchenAddress,
        paperMm: saved.paperMm,
      );
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) _lastError = 'Printer did not accept data';
      return ok;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[BillPrinter] print failed: $e');
      return false;
    }
  }

  static Future<List<int>> _buildBillBytes({
    required OrderModel order,
    required String kitchenName,
    required String kitchenAddress,
    required int paperMm,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(paperMm == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final shortId = order.id.length >= 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase();
    final paidOnline = order.paymentId.isNotEmpty;

    double itemsTotal = 0;
    for (final item in order.items) {
      itemsTotal += item.priceAtOrder * item.quantity;
    }
    // Fall back to order amount split when item prices are missing.
    if (itemsTotal <= 0 && order.items.isNotEmpty) {
      itemsTotal = order.amount;
    }

    List<int> bytes = [];
    bytes += gen.text(kitchenName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    if (kitchenAddress.isNotEmpty) {
      bytes += gen.text(kitchenAddress, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += gen.hr();
    bytes += gen.row([
      PosColumn(text: 'Order #$shortId', width: 6),
      PosColumn(text: dateStr, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += gen.text(paidOnline ? 'ONLINE PAID' : 'CASH ON DELIVERY',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += gen.hr();
    for (final item in order.items) {
      final qty = item.quantity;
      final rate = item.priceAtOrder > 0
          ? item.priceAtOrder
          : (order.items.isNotEmpty ? itemsTotal / order.items.length / (qty == 0 ? 1 : qty) : 0);
      final lineTotal = rate * qty;
      bytes += gen.row([
        PosColumn(text: '$qty x ${item.menuItemName}', width: 8),
        PosColumn(
            text: 'Rs.${lineTotal.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (item.specialInstructions.isNotEmpty) {
        bytes += gen.text('  Note: ${item.specialInstructions}');
      }
    }
    bytes += gen.hr();
    bytes += gen.row([
      PosColumn(text: 'Item Total', width: 6),
      PosColumn(
          text: 'Rs.${itemsTotal.toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += gen.row([
      PosColumn(text: 'Delivery', width: 6),
      PosColumn(text: 'FREE', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (order.tip > 0) {
      bytes += gen.row([
        PosColumn(text: 'Tip', width: 6),
        PosColumn(
            text: 'Rs.${order.tip.toStringAsFixed(0)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += gen.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: 'Rs.${order.amount.toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    bytes += gen.hr();
    if (order.deliveryAddress.isNotEmpty) {
      bytes += gen.text('Deliver to:');
      bytes += gen.text(order.deliveryAddress);
      bytes += gen.hr();
    }
    bytes += gen.text('Thank you! Visit again.',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += gen.text('Powered by MEALIN', styles: const PosStyles(align: PosAlign.center));
    bytes += gen.feed(2);
    bytes += gen.cut();
    return bytes;
  }
}
