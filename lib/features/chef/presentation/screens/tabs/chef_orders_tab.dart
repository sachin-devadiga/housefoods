import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../customer/domain/models/order_model.dart';
import '../../../../customer/presentation/providers/order_provider.dart';
import '../../providers/chef_provider.dart';
import '../../widgets/chef_order_card.dart';

class ChefOrdersTab extends StatefulWidget {
  const ChefOrdersTab({super.key});

  @override
  State<ChefOrdersTab> createState() => _ChefOrdersTabState();
}

class _ChefOrdersTabState extends State<ChefOrdersTab> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chefProvider = context.read<ChefProvider>();
      if (chefProvider.myKitchen != null) {
        context.read<OrderProvider>().fetchKitchenOrders(chefProvider.myKitchen!['id']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.customerOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text("No active subscriptions found.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.customerOrders.length,
            itemBuilder: (context, index) {
              final order = provider.customerOrders[index];
              return ChefOrderCard(
                order: order,
                onUpdateStatus: () {
                  _showUpdateStatusDialog(context, order);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showUpdateStatusDialog(BuildContext context, OrderModel order) {
    final orderProvider = context.read<OrderProvider>();
    final chefProvider = context.read<ChefProvider>();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text("Update Order Status", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _statusTile(context, "Preparing", Icons.soup_kitchen, Colors.orange, order, orderProvider, chefProvider),
              _statusTile(context, "Out for Delivery", Icons.delivery_dining, Colors.blue, order, orderProvider, chefProvider),
              _statusTile(context, "Delivered", Icons.check_circle, Colors.green, order, orderProvider, chefProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _statusTile(BuildContext context, String status, IconData icon, Color color, OrderModel order, OrderProvider op, ChefProvider cp) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(status),
      onTap: () async {
        await op.updateStatus(order.id, status, cp.myKitchen!['id']);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
