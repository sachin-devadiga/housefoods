import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';

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
                final deliveryId = delivery['deliveryId'] ?? delivery['id'];
                final status = delivery['status'] ?? 'assigned';

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
                            Text('#${_shortId(delivery['orderId'])}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(delivery['deliveryAddress'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.grey, size: 18),
                            const SizedBox(width: 6),
                            Text(delivery['customerName'] ?? 'Customer'),
                          ],
                        ),
                        if (status == 'assigned') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (deliveryId != null) {
                                  provider.updateDeliveryStatus(deliveryId, 'picked_up');
                                }
                              },
                              icon: const Icon(Icons.delivery_dining),
                              label: const Text('Mark Picked Up'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          ),
                        ],
                        if (status == 'picked_up') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (deliveryId != null) {
                                  provider.updateDeliveryStatus(deliveryId, 'delivered');
                                }
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Mark Delivered'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
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
}
