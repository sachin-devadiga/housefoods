import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../providers/admin_provider.dart';

class ManageKitchensScreen extends StatefulWidget {
  const ManageKitchensScreen({super.key});

  @override
  State<ManageKitchensScreen> createState() => _ManageKitchensScreenState();
}

class _ManageKitchensScreenState extends State<ManageKitchensScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllKitchens();
    });
  }

  void _showStatusDialog(BuildContext context, dynamic kitchen) {
    final provider = context.read<AdminProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Manage Kitchen Status", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(kitchen['name'] ?? ''),
            ),
            const Divider(),
            _statusTile(context, "Approve", "approved", Colors.green, kitchen['id'], provider),
            _statusTile(context, "Reject", "rejected", Colors.red, kitchen['id'], provider),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(BuildContext context, String label, String status, Color color, int kitchenId, AdminProvider provider) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 16),
      title: Text(label),
      onTap: () async {
        await provider.updateKitchenStatus(kitchenId, status);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Directory"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allKitchens.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.allKitchens.isEmpty) {
            return const Center(child: Text("No kitchens found."));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchAllKitchens(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.allKitchens.length,
              itemBuilder: (context, index) {
                final kitchen = provider.allKitchens[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: AppCachedImage(
                          imageUrl: kitchen['image_url'] ?? '',
                          height: 50,
                          width: 50,
                          borderRadius: 8,
                        ),
                        title: Text(kitchen['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Chef: ${kitchen['chef_details']?['name'] ?? 'Chef'}"),
                        trailing: _buildStatusBadge(kitchen['status'] ?? ''),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  (kitchen['rating'] ?? 0.0).toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  " (${kitchen['total_ratings']} ratings)",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _showStatusDialog(context, kitchen),
                              child: const Text("Update Status", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      case 'suspended': color = Colors.red; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
