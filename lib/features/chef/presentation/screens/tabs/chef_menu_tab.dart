import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../customer/domain/models/subscription_plan_model.dart';
import '../../../../customer/presentation/widgets/subscription_plan_card.dart';
import '../../providers/chef_provider.dart';
import '../add_plan_screen.dart';
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

          // Case 1: No Kitchen Setup Yet
          if (provider.myKitchen == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storefront, size: 80, color: AppTheme.secondaryColor),
                    const SizedBox(height: 24),
                    const Text(
                      "Setup Your Kitchen",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "To start selling your home-cooked meals, you first need to register your kitchen details.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const KitchenSetupScreen())
                      ).then((_) => _loadData()),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                      child: const Text("Get Started"),
                    ),
                  ],
                ),
              ),
            );
          }

          // Case 2: Kitchen is Pending Approval
          if (provider.myKitchen!['status'] == 'pending') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text(
                      "Verification Pending",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Your kitchen application is being reviewed by our team. This usually takes 24-48 hours.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: _loadData,
                      child: const Text("Refresh Status"),
                    ),
                  ],
                ),
              ),
            );
          }

          // Case 3: Kitchen is Rejected
          if (provider.myKitchen!['status'] == 'rejected') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 80, color: Colors.red),
                    const SizedBox(height: 24),
                    const Text(
                      "Application Rejected",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Unfortunately, your kitchen application was not approved. Please contact support for more details.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          // Case 4: Kitchen approved but no plans added
          if (provider.myPlans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Your kitchen is live!", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Now add your first subscription plan.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                    child: const Text("Create a Plan"),
                  ),
                ],
              ),
            );
          }

          // Case 5: Kitchen and Plans exist
          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu, size: 20),
                    const SizedBox(width: 8),
                    const Text("Menu Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDishesScreen())),
                      icon: const Icon(Icons.restaurant, size: 18),
                      label: const Text("Manage"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.myDishes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("No dishes added yet. Add dishes from the menu tab.", style: TextStyle(color: Colors.grey[600])),
                    ),
                  )
                else
                  ...provider.myDishes.take(3).map((dish) => Card(
                    child: ListTile(
                      leading: Icon(dish['is_veg'] == true ? Icons.circle : Icons.circle, color: dish['is_veg'] == true ? Colors.green : Colors.red, size: 12),
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
                const SizedBox(height: 24),
                const Text("Subscription Plans", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...provider.myPlans.map((planData) {
                  final plan = SubscriptionPlanModel.fromMap(planData, planData['id']?.toString() ?? '');
                  return Card(
                    child: ListTile(
                      title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text("₹${plan.price.toStringAsFixed(0)} • ${plan.durationDays} days"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showEditPlanDialog(context, provider, planData),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _confirmDeletePlan(context, provider, planData),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen())),
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  void _confirmDeletePlan(BuildContext context, ChefProvider provider, Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Plan"),
        content: Text("Delete '${plan['name']}'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deletePlan(plan['id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditPlanDialog(BuildContext context, ChefProvider provider, Map<String, dynamic> plan) {
    final nameCtrl = TextEditingController(text: plan['name'] ?? '');
    final priceCtrl = TextEditingController(text: '${plan['price'] ?? ''}');
    final durationCtrl = TextEditingController(text: '${plan['duration_days'] ?? ''}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Plan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Plan Name")),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price (₹)"), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: "Duration (days)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.updatePlan(plan['id'], {
                'name': nameCtrl.text,
                'price': double.tryParse(priceCtrl.text) ?? 0,
                'duration_days': int.tryParse(durationCtrl.text) ?? 0,
              });
            },
            child: const Text("Save"),
          ),
        ],
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
    bool isVeg = dish['is_veg'] ?? false;
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
                    activeColor: Colors.green,
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
