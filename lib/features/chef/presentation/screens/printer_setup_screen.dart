import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/theme/app_theme.dart';
import '../services/bill_printer_service.dart';

/// One-time Bluetooth bill-printer setup for the resto app.
/// Lists paired printers, connects, saves choice + paper size, test-prints.
class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  List<BluetoothInfo> _devices = [];
  bool _scanning = false;
  bool _working = false;
  String? _savedMac;
  String _savedName = '';
  int _paperMm = 80;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _refreshDevices();
  }

  Future<void> _loadSaved() async {
    final saved = await BillPrinterService.loadPrinter();
    if (mounted && saved != null) {
      setState(() {
        _savedMac = saved.mac;
        _savedName = saved.name;
        _paperMm = saved.paperMm;
      });
    }
  }

  Future<bool> _ensureBtPermission() async {
    var scan = await Permission.bluetoothScan.request();
    var connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bluetooth permission is needed to find your printer')),
      );
    }
    return false;
  }

  Future<void> _refreshDevices() async {
    if (!await _ensureBtPermission()) return;
    setState(() => _scanning = true);
    final list = await BillPrinterService.pairedDevices();
    if (mounted) {
      setState(() {
        _devices = list;
        _scanning = false;
      });
    }
    if (list.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No paired printers found. Pair your thermal printer in phone Settings → Bluetooth first.')),
      );
    }
  }

  Future<void> _selectDevice(BluetoothInfo device) async {
    setState(() => _working = true);
    final ok = await BillPrinterService.connect(device.macAdress);
    if (ok) {
      await BillPrinterService.savePrinter(
          mac: device.macAdress, name: device.name, paperMm: _paperMm);
      if (mounted) {
        setState(() {
          _savedMac = device.macAdress;
          _savedName = device.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Connected to ${device.name}'),
              backgroundColor: AppTheme.secondaryColor),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Could not connect. Make sure ${device.name} is ON and paired.'),
            backgroundColor: AppTheme.errorColor),
      );
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _testPrint() async {
    setState(() => _working = true);
    final ok = await BillPrinterService.testPrint();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Test print sent!'
            : 'Test failed: ${BillPrinterService.lastError ?? 'unknown'}'),
        backgroundColor: ok ? AppTheme.secondaryColor : AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Printer'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_savedMac != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Connected printer',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_savedName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _working
                        ? null
                        : () async {
                            await BillPrinterService.clearPrinter();
                            if (mounted) setState(() => _savedMac = null);
                          },
                    child: const Text('Forget'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text('Paper size', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [58, 80].map((mm) {
              final sel = _paperMm == mm;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text('${mm}mm'),
                  selected: sel,
                  onSelected: (_) async {
                    setState(() => _paperMm = mm);
                    final saved = await BillPrinterService.loadPrinter();
                    if (saved != null) {
                      await BillPrinterService.savePrinter(
                          mac: saved.mac, name: saved.name, paperMm: mm);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paired printers', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _scanning ? null : _refreshDevices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Rescan'),
              ),
            ],
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No paired Bluetooth devices.\n\n1. Switch ON your thermal printer\n2. Pair it in phone Settings → Bluetooth\n3. Tap Rescan here',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._devices.map((d) {
              final isSaved = d.macAdress == _savedMac;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.print_outlined,
                      color: isSaved ? AppTheme.secondaryColor : Colors.grey),
                  title: Text(d.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(d.macAdress,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: _working
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : isSaved
                          ? const Icon(Icons.check_circle, color: AppTheme.secondaryColor)
                          : const Text('CONNECT',
                              style: TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.bold)),
                  onTap: (_working || isSaved) ? null : () => _selectDevice(d),
                ),
              );
            }),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              onPressed: (_working || _savedMac == null) ? null : _testPrint,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('PRINT TEST BILL',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
