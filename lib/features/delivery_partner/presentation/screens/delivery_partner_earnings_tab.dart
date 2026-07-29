import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_partner_provider.dart';

String _shortId(dynamic id, {int length = 8}) {
  final s = id?.toString() ?? '';
  return s.length >= length ? s.substring(0, length).toUpperCase() : s;
}

String _safeCurrency(dynamic value) {
  if (value is num) return '₹${value.toStringAsFixed(0)}';
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed != null && parsed.isFinite) return '₹${parsed.toStringAsFixed(0)}';
  return '₹0';
}

class DeliveryPartnerEarningsTab extends StatelessWidget {
  const DeliveryPartnerEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: Consumer<DeliveryPartnerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.myDeliveries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchMyDeliveries(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('Total Earnings', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('₹${provider.totalEarnings.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statItem('Today', '₹${provider.todayEarnings.toStringAsFixed(0)}'),
                              _statItem('This Week', '₹${provider.weeklyEarnings.toStringAsFixed(0)}'),
                              _statItem('Deliveries', '${provider.totalDeliveries}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Recent Deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                  const SizedBox(height: 12),
                  if (provider.myDeliveries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No delivery history yet', style: TextStyle(color: Colors.grey[500])),
                      ),
                    )
                  else
                    ...provider.myDeliveries
                        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'delivered')
                        .map((d) => ListTile(
                              leading: const Icon(Icons.check_circle, color: Colors.green),
                              title: Text('Delivery #${_shortId(d['orderId'])}'),
                              subtitle: Text(d['deliveryAddress'] ?? ''),
                              trailing: Text(_safeCurrency(d['deliveryFee']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
