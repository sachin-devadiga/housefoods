import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';
import 'delivery_otp_screen.dart';
import 'delivery_tracking_map_screen.dart';

String _shortId(dynamic id, {int length = 8}) {
  final s = id?.toString() ?? '';
  return s.length >= length ? s.substring(0, length).toUpperCase() : s;
}

class DeliveryPartnerDeliveriesTab extends StatelessWidget {
  const DeliveryPartnerDeliveriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Deliveries')),
      body: Consumer<DeliveryPartnerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.myDeliveries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myDeliveries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delivery_dining, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No active deliveries', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchMyDeliveries(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.myDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = provider.myDeliveries[index];
                final deliveryId = delivery['id'];
                final status = delivery['delivery_status'] ?? 'assigned';
                final customerDetails = delivery['customer_details'] as Map<String, dynamic>?;
                final customerName = customerDetails?['name'] as String? ?? delivery['customer_name'] ?? 'Customer';
                final deliveryAddress = delivery['delivery_address'] ?? '';
                final kitchenName = delivery['kitchen_name'] ?? delivery['kitchen_details']?['name'] ?? 'Kitchen';
                final deliveryFee = delivery['delivery_fee'] ?? 0;

                Color statusColor;
                String statusText;
                IconData statusIcon;

                switch (status) {
                  case 'assigned':
                    statusColor = Colors.orange;
                    statusText = 'Pick Up';
                    statusIcon = Icons.trip_origin;
                    break;
                  case 'picked_up':
                    statusColor = Colors.blue;
                    statusText = 'On Route';
                    statusIcon = Icons.delivery_dining;
                    break;
                  case 'delivered':
                    statusColor = Colors.green;
                    statusText = 'Delivered';
                    statusIcon = Icons.check_circle;
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusText = status;
                    statusIcon = Icons.help;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 24),
                            const SizedBox(width: 8),
                            Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('#${_shortId(delivery['id'])}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.restaurant, color: Colors.orange, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(kitchenName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(deliveryAddress,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.grey, size: 18),
                            const SizedBox(width: 6),
                            Text(customerName),
                            const Spacer(),
                            if (deliveryFee is num && deliveryFee > 0)
                              Text('₹${deliveryFee.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        if (status == 'assigned') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (deliveryId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DeliveryTrackingMapScreen(
                                            deliveryId: deliveryId,
                                            kitchenName: kitchenName,
                                            deliveryAddress: deliveryAddress,
                                            status: status,
                                            delivery: delivery,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('View Map'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (deliveryId != null) {
                                      _confirmAction(
                                        context,
                                        title: 'Mark as Picked Up?',
                                        message: 'Confirm you have picked up the meal from $kitchenName',
                                        onConfirm: () => provider.updateDeliveryStatus(deliveryId, 'picked_up'),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delivery_dining),
                                  label: const Text('Mark Picked Up'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (status == 'picked_up') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DeliveryTrackingMapScreen(
                                          deliveryId: deliveryId,
                                          kitchenName: kitchenName,
                                          deliveryAddress: deliveryAddress,
                                          status: status,
                                          delivery: delivery,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('View Map'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (deliveryId != null) {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DeliveryOtpScreen(
                                            deliveryId: deliveryId,
                                            customerName: customerName,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        provider.fetchMyDeliveries();
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.lock_outline),
                                  label: const Text('Enter OTP & Deliver'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  void _confirmAction(BuildContext context, {required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
