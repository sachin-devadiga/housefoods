import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/presentation/providers/order_provider.dart';
import '../providers/chef_provider.dart';

class DispatchHistoryScreen extends StatefulWidget {
  const DispatchHistoryScreen({super.key});

  @override
  State<DispatchHistoryScreen> createState() => _DispatchHistoryScreenState();
}

class _DispatchHistoryScreenState extends State<DispatchHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chefProvider = context.read<ChefProvider>();
      final kitchenId = chefProvider.myKitchen?['id'];
      if (kitchenId != null) {
        context.read<OrderProvider>().fetchKitchenDispatchHistory(kitchenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dispatch History"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.kitchenDispatchHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.kitchenDispatchHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "No historical logs found.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.kitchenDispatchHistory.length,
              itemBuilder: (context, index) {
                final log = provider.kitchenDispatchHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: log.status == 'delivered' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      child: Icon(
                        log.status == 'delivered' ? Icons.check : Icons.close,
                        color: log.status == 'delivered' ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      "Delivery on ${DateFormat('dd MMM yyyy').format(log.date)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      "Order ID: ${log.orderId.substring(0, 8).toUpperCase()}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Text(
                      log.status.toUpperCase(),
                      style: TextStyle(
                        color: log.status == 'delivered' ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
