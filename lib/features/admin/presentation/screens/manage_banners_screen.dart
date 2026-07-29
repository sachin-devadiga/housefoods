import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchBanners();
    });
  }

  void _showAddBannerDialog() {
    final provider = context.read<AdminProvider>();
    final imageUrlController = TextEditingController();
    final actionIdController = TextEditingController();
    String actionType = 'kitchen';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Add Banner"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: imageUrlController,
                decoration: const InputDecoration(labelText: "Image URL", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: actionType,
                decoration: const InputDecoration(labelText: "Action Type"),
                items: const [
                  DropdownMenuItem(value: 'kitchen', child: Text("Open Kitchen")),
                  DropdownMenuItem(value: 'coupon', child: Text("Open Coupon")),
                  DropdownMenuItem(value: 'none', child: Text("No Action")),
                ],
                onChanged: (val) => setModalState(() => actionType = val!),
              ),
              if (actionType != 'none')
                TextField(
                  controller: actionIdController,
                  decoration: const InputDecoration(labelText: "Kitchen/Coupon ID"),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                final banner = {
                  'id': '',
                  'image_url': imageUrlController.text.trim(),
                  'action_type': actionType,
                  'action_id': actionIdController.text.trim(),
                };
                provider.addBanner(banner);
                Navigator.pop(context);
              },
              child: const Text("Publish"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Banners"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.banners.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.banners.isEmpty) {
            return const Center(child: Text("No active banners. Add one to get started!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.banners.length,
            itemBuilder: (context, index) {
              final banner = provider.banners[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Image.network(banner['image_url'] ?? '', height: 150, width: double.infinity, fit: BoxFit.cover),
                    ListTile(
                      title: Text("Action: ${(banner['action_type'] ?? '').toString().toUpperCase()}"),
                      subtitle: Text("ID: ${banner['action_id'] ?? 'N/A'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => provider.deleteBanner(banner['id']),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBannerDialog,
        backgroundColor: Colors.indigo,
        label: const Text("Add Banner", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
      ),
    );
  }
}
