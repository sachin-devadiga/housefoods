import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.userProfile?['uid'] ?? '';
      if (uid.isNotEmpty) {
        context.read<OrderProvider>().fetchCustomerOrders(uid);
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
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  "No orders yet.",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final uid = authProvider.userProfile?['uid'] ?? '';
            if (uid.isNotEmpty) {
              await provider.fetchCustomerOrders(uid);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.customerOrders.length,
            itemBuilder: (context, index) {
              return OrderCard(order: provider.customerOrders[index]);
            },
          ),
        );
      },
    );
  }
}
