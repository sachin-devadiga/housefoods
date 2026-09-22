import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../customer/domain/models/order_model.dart';
import '../../../../customer/presentation/providers/order_provider.dart';
import '../../providers/chef_provider.dart';
import '../../widgets/chef_order_card.dart';
import '../../services/bill_printer_service.dart';

class ChefOrdersTab extends StatefulWidget {
  const ChefOrdersTab({super.key});

  @override
  State<ChefOrdersTab> createState() => _ChefOrdersTabState();
}

class _ChefOrdersTabState extends State<ChefOrdersTab> {
  static const List<int> _prepOptions = [10, 15, 20, 30, 45];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final chefProvider = context.read<ChefProvider>();
    final kitchenId = chefProvider.myKitchen?['id']?.toString();
    if (kitchenId != null && kitchenId.isNotEmpty) {
      await context.read<OrderProvider>().fetchKitchenOrders(kitchenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.customerOrders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.customerOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No orders yet.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('New orders will appear here with an alarm.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.customerOrders.length,
            itemBuilder: (context, index) {
              final order = provider.customerOrders[index];
              return ChefOrderCard(
                order: order,
                onAccept: () => _showPrepTimeSheet(order),
                onReject: () => _confirmReject(order),
                onMarkReady: () => _setStatus(order, 'Preparing', 'Order marked ready for dispatch'),
                onPrintBill: () => _printBill(order),
              );
            },
          ),
        );
      },
    );
  }

  String? _kitchenId() {
    return context.read<ChefProvider>().myKitchen?['id']?.toString();
  }

  Future<void> _setStatus(OrderModel order, String status, String okMessage,
      {int? preparationTime}) async {
    final kitchenId = _kitchenId();
    if (kitchenId == null || kitchenId.isEmpty) return;
    final ok = await context
        .read<OrderProvider>()
        .updateStatus(order.id, status, kitchenId, preparationTime: preparationTime);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? okMessage
            : 'Update failed: ${context.read<OrderProvider>().errorMessage ?? 'try again'}'),
        backgroundColor: ok ? AppTheme.secondaryColor : AppTheme.errorColor,
      ),
    );
  }

  void _showPrepTimeSheet(OrderModel order) {
    int selected = 20;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accept order #${order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id}?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('How long to prepare? The customer will be notified.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _prepOptions.map((mins) {
                  final isSel = selected == mins;
                  return ChoiceChip(
                    label: Text('$mins min'),
                    selected: isSel,
                    onSelected: (_) => setSheetState(() => selected = mins),
                    selectedColor: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    side: BorderSide(
                        color: isSel ? AppTheme.secondaryColor : Colors.grey.shade300),
                    labelStyle: TextStyle(
                      color: isSel ? AppTheme.secondaryColor : Colors.black87,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _setStatus(order, 'Accept', 'Order accepted • ~$selected min',
                        preparationTime: selected);
                  },
                  child: const Text('CONFIRM ACCEPT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReject(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject order?'),
        content: const Text(
            'The customer will be notified immediately. Only reject if you really cannot fulfil this order.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Order')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(ctx);
              _setStatus(order, 'Reject', 'Order rejected');
            },
            child: const Text('REJECT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printBill(OrderModel order) async {
    final chefProvider = context.read<ChefProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final kitchen = chefProvider.myKitchen;
    final kitchenName = (kitchen?['name'] ?? 'Kitchen').toString();
    final kitchenAddress = (kitchen?['address'] ?? '').toString();

    if (!await BillPrinterService.isConfigured()) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('No printer set up. Connect one from Profile → Bill Printer.')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Printing bill…'), duration: Duration(seconds: 2)),
    );
    final ok = await BillPrinterService.printOrderBill(
      order: order,
      kitchenName: kitchenName,
      kitchenAddress: kitchenAddress,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Bill sent to printer' : 'Print failed: ${BillPrinterService.lastError ?? 'printer unreachable'}'),
        backgroundColor: ok ? AppTheme.secondaryColor : AppTheme.errorColor,
      ),
    );
  }
}
