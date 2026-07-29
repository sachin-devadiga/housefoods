import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../providers/admin_provider.dart';

class VerifyKitchensScreen extends StatefulWidget {
  const VerifyKitchensScreen({super.key});

  @override
  State<VerifyKitchensScreen> createState() => _VerifyKitchensScreenState();
}

class _VerifyKitchensScreenState extends State<VerifyKitchensScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPendingKitchens();
    });
  }

  void _viewDocument(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: Text(title), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
            AppCachedImage(imageUrl: url, height: 400, width: double.infinity),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Verification"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.pendingKitchens.isEmpty) {
            return const Center(child: Text("No pending applications"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingKitchens.length,
            itemBuilder: (context, index) {
              final kitchen = provider.pendingKitchens[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCachedImage(imageUrl: kitchen['image_url'] ?? '', height: 150, width: double.infinity, borderRadius: 16),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kitchen['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text("Chef: ${kitchen['chef_details']?['name'] ?? 'Chef'}", style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text("KYC & COMPLIANCE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 8),
                          Text("FSSAI No: ${kitchen['fssai_number'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _docButton("ID Proof", kitchen['id_proof_url']),
                              const SizedBox(width: 12),
                              _docButton("License", kitchen['license_url']),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => provider.updateKitchenStatus(kitchen['id'], 'rejected'),
                                child: const Text("REJECT", style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => provider.updateKitchenStatus(kitchen['id'], 'approved'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text("APPROVE KITCHEN"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _docButton(String label, String? url) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: url == null ? null : () => _viewDocument(url, label),
        icon: const Icon(Icons.description_outlined, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.indigo,
          side: const BorderSide(color: Colors.indigo),
        ),
      ),
    );
  }
}
