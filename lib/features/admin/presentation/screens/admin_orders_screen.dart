import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Orders')),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.orders.length,
              itemBuilder: (context, index) {
                final order = provider.orders[index];
                final status = order['status'] ?? 'pending';
                final total = order['total_amount'] ?? order['total'] ?? 0;
                final kitchenName = order['kitchen_name'] ?? order['kitchen_details']?['name'] ?? 'Kitchen';
                final customerName = order['customer_name'] ?? order['customer']?['name'] ?? 'Customer';
                final address = order['delivery_address'] ?? '';
                final createdAt = order['created_at'] ?? '';

                Color statusColor;
                IconData statusIcon;
                switch (status) {
                  case 'delivered':
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'cancelled':
                    statusColor = Colors.red;
                    statusIcon = Icons.cancel;
                    break;
                  case 'in_progress':
                  case 'out_for_delivery':
                    statusColor = Colors.blue;
                    statusIcon = Icons.local_shipping;
                    break;
                  default:
                    statusColor = Colors.orange;
                    statusIcon = Icons.pending;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Order #${order['id'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toString().toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        _detailRow(Icons.restaurant, 'Kitchen', kitchenName),
                        _detailRow(Icons.person, 'Customer', customerName),
                        if (address.isNotEmpty) _detailRow(Icons.location_on, 'Address', address),
                        _detailRow(Icons.currency_rupee, 'Total', '₹$total'),
                        if (createdAt.toString().isNotEmpty)
                          _detailRow(Icons.access_time, 'Date', createdAt.toString().substring(0, createdAt.toString().length > 16 ? 16 : createdAt.toString().length)),
                      ],
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
