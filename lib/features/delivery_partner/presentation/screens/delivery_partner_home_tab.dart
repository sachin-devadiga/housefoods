import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';
import 'delivery_document_upload_screen.dart';

class DeliveryPartnerHomeTab extends StatefulWidget {
  const DeliveryPartnerHomeTab({super.key});

  @override
  State<DeliveryPartnerHomeTab> createState() => _DeliveryPartnerHomeTabState();
}

class _DeliveryPartnerHomeTabState extends State<DeliveryPartnerHomeTab> {
  bool? _isVerified;
  late ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
    _checkVerification();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    try {
      final data = await _api.get(AppConstants.deliveryAvailabilityEndpoint);
      if (mounted) setState(() => _isVerified = data['is_verified'] == true);
    } catch (_) {
      if (mounted) setState(() => _isVerified = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Deliveries')),
      body: Consumer<DeliveryPartnerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_isVerified == false) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 80, color: Colors.orange[200]),
                    const SizedBox(height: 16),
                    Text('Verification Pending', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                    const SizedBox(height: 8),
                    Text('Upload your documents and wait for admin approval to start delivering.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryDocumentUploadScreen())),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Documents'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _checkVerification,
                      child: const Text('Refresh Status'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.errorMessage != null && provider.availableOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(provider.errorMessage!, textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchAvailableOrders(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.availableOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trip_origin, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No deliveries available', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Check back later for new orders', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchAvailableOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.availableOrders.length,
              itemBuilder: (context, index) {
                final order = provider.availableOrders[index];
                final orderId = order['orderId'];
                if (orderId == null) return const SizedBox.shrink();
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
                            const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(order['deliveryAddress'] ?? 'Unknown address',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.restaurant, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text('From: ${order['kitchenName'] ?? 'Kitchen'}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.currency_rupee, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text('Delivery fee: ₹${order['deliveryFee'] ?? '0'}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => provider.acceptDelivery(orderId),
                            child: const Text('Accept Delivery'),
                          ),
                        ),
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
