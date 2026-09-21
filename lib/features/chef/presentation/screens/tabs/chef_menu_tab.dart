import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../providers/chef_provider.dart';
import '../add_dish_screen.dart';
import '../kitchen_setup_screen.dart';
import '../manage_dishes_screen.dart';

class ChefMenuTab extends StatefulWidget {
  const ChefMenuTab({super.key});

  @override
  State<ChefMenuTab> createState() => _ChefMenuTabState();
}

class _ChefMenuTabState extends State<ChefMenuTab> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.userProfile?['uid'] ?? '';
      if (uid.isNotEmpty) {
        context.read<ChefProvider>().fetchMyKitchen(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ChefProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myKitchen == null) {
            return _buildEmptyState(
              icon: Icons.storefront,
              title: "Setup Your Kitchen",
              subtitle: "Register your kitchen to start selling meals.",
              actionLabel: "Get Started",
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KitchenSetupScreen()),
              ).then((_) => _loadData()),
            );
          }

          if (provider.myKitchen!['status'] == 'pending') {
            return _buildEmptyState(
              icon: Icons.pending_actions,
              iconColor: Colors.orange,
              title: "Verification Pending",
              subtitle: "Your kitchen application is being reviewed. This usually takes 24-48 hours.",
              actionLabel: "Refresh Status",
              onAction: _loadData,
              isOutlined: true,
            );
          }

          if (provider.myKitchen!['status'] == 'rejected') {
            return _buildEmptyState(
              icon: Icons.error_outline,
              iconColor: Colors.red,
              title: "Application Rejected",
              subtitle: "Your kitchen application was not approved. Please contact support.",
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu, size: 20),
                    const SizedBox(width: 8),
                    const Text("Your Menu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDishesScreen())),
                      icon: const Icon(Icons.restaurant, size: 18),
                      label: const Text("Manage All"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.myDishes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.fastfood_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text("No dishes added yet", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("Tap + to add your first dish", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...provider.myDishes.map((dish) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: (dish['is_veg'] == true || dish['isVeg'] == true) ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(dish['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text("₹${dish['price'] ?? '0'}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showEditDishDialog(context, provider, dish),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _confirmDeleteDish(context, provider, dish),
                          ),
                        ],
                      ),
                    ),
                  )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<ChefProvider>(
        builder: (context, provider, child) {
          if (provider.myKitchen == null || provider.myKitchen!['status'] != 'approved') return const SizedBox.shrink();
          return FloatingActionButton(
            backgroundColor: AppTheme.secondaryColor,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDishScreen())),
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    Color iconColor = const Color(0xFF8D6E63),
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    bool isOutlined = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: iconColor),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              isOutlined
                  ? OutlinedButton(onPressed: onAction, child: Text(actionLabel))
                  : ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                      child: Text(actionLabel),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDish(BuildContext context, ChefProvider provider, Map<String, dynamic> dish) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Dish"),
        content: Text("Delete '${dish['name']}' from your menu?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteDish(dish['id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDishDialog(BuildContext context, ChefProvider provider, Map<String, dynamic> dish) {
    final nameCtrl = TextEditingController(text: dish['name'] ?? '');
    final priceCtrl = TextEditingController(text: '${dish['price'] ?? ''}');
    final descCtrl = TextEditingController(text: dish['description'] ?? '');
    bool isVeg = dish['is_veg'] ?? dish['isVeg'] ?? false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Edit Dish"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Dish Name")),
              const SizedBox(height: 8),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price (₹)"), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Veg: "),
                  Switch(
                    value: isVeg,
                    onChanged: (v) => setDialogState(() => isVeg = v),
                    activeThumbColor: Colors.green,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.updateDish(dish['id'], {
                  'name': nameCtrl.text,
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'description': descCtrl.text,
                  'is_veg': isVeg,
                });
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
