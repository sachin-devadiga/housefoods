import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../customer/domain/models/subscription_plan_model.dart';
import '../../../../customer/presentation/widgets/subscription_plan_card.dart';
import '../../providers/chef_provider.dart';
import '../add_plan_screen.dart';
import '../kitchen_setup_screen.dart';

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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.myPlans.length,
              itemBuilder: (context, index) {
                final planData = provider.myPlans[index];
                final plan = SubscriptionPlanModel.fromMap(planData, planData['id']?.toString() ?? '');
                return SubscriptionPlanCard(
                  plan: plan,
                  onSelect: () {
                    // Options for Chefs to Edit or Delete
                  },
                );
              },
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
}
