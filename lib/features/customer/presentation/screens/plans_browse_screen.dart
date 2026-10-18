import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/add_address_screen.dart';
import '../../domain/models/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../widgets/meal_plan_card.dart';
import 'plan_detail_screen.dart';

/// Browse feed of meal plans, grouped by kitchen and ordered nearest first by
/// the backend.
///
/// `subscriptions/plans/` 400s with "Add a delivery address before browsing
/// plans" when the customer has none, so the address list is loaded up front
/// and the same case is shown as a prompt rather than an error.
class PlansBrowseScreen extends StatefulWidget {
  const PlansBrowseScreen({super.key});

  @override
  State<PlansBrowseScreen> createState() => _PlansBrowseScreenState();
}

class _PlansBrowseScreenState extends State<PlansBrowseScreen> {
  UserModel? _user;
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    UserModel? user;
    if (uid.isNotEmpty) {
      user = await UserRepositoryImpl().getUser(uid);
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _isUserLoading = false;
    });
    if (user != null && user.addresses.isNotEmpty) {
      context.read<SubscriptionProvider>().fetchPlans();
    }
  }

  Future<void> _addAddressFlow() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add an address')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!)),
    );
    await _loadUser();
  }

  Future<void> _refresh() async {
    await _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = (_user?.addresses.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Plans')),
      body: _isUserLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasAddress
              ? _buildNoAddressState()
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _refresh,
                  child: Consumer<SubscriptionProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.plans.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: const [
                            MealPlanCardShimmer(),
                            MealPlanCardShimmer(),
                            MealPlanCardShimmer(),
                          ],
                        );
                      }

                      if (provider.error != null && provider.plans.isEmpty) {
                        return _buildErrorState(provider);
                      }

                      if (provider.plans.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: _buildGroups(provider),
                      );
                    },
                  ),
                ),
    );
  }

  List<Widget> _buildGroups(SubscriptionProvider provider) {
    final widgets = <Widget>[];
    provider.plansByKitchen.forEach((kitchen, plans) {
      final distance = plans.first.distanceLabel;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                kitchen,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (distance != null)
              Text(distance, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          ],
        ),
      ));
      widgets.addAll(plans.map((MealPlanModel plan) => MealPlanCard(
            plan: plan,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanDetailScreen(plan: plan),
                ),
              );
            },
          )));
      widgets.add(const SizedBox(height: 10));
    });
    widgets.add(const SizedBox(height: 70));
    return widgets;
  }

  Widget _buildNoAddressState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 14),
            const Text(
              'Add a delivery address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'We need your address to find kitchens that deliver to you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: _addAddressFlow,
              child: const Text('Add Address', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Column(
          children: [
            Icon(Icons.no_meals_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No meal plans nearby',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No kitchen within 15 km has published a plan yet. Plans are '
                'added by kitchens — check again soon, or keep browsing '
                'one-time orders in the meantime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(SubscriptionProvider provider) {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () => provider.fetchPlans(),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}