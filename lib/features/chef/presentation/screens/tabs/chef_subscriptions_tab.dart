import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_cached_image.dart';
import '../../../domain/models/meal_plan_model.dart';
import '../../providers/chef_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../plan_subscribers_screen.dart';
import '../weekly_plan_builder_screen.dart';

/// Subscription plans for this kitchen: the published plans, plus the entry
/// point into the weekly 7×3 builder.
class ChefSubscriptionsTab extends StatefulWidget {
  const ChefSubscriptionsTab({super.key});

  @override
  State<ChefSubscriptionsTab> createState() => _ChefSubscriptionsTabState();
}

class _ChefSubscriptionsTabState extends State<ChefSubscriptionsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    final kitchenId =
        context.read<ChefProvider>().myKitchen?['id']?.toString() ?? '';
    if (kitchenId.isEmpty) return;
    await context.read<MealPlanProvider>().fetchPlans(kitchenId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MealPlanProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.plans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _loadPlans,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meal Plans',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlanSubscribersScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Subscribers'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provider.plans.isEmpty)
                _buildEmptyState(provider.errorMessage != null)
              else
                for (final plan in provider.plans) _buildPlanCard(plan),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WeeklyPlanBuilderScreen(),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('BUILD WEEKLY PLAN',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 12),
              const Text(
                'The weekly template is 7 days × 3 meals. Each cell holds the '
                'dishes cooked for that meal, snapshotted at publish time.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool hadError) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No meal plans yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hadError
                ? 'Could not reach the server. Pull down to retry.'
                : 'Build a weekly plan below to start taking subscriptions.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(MealPlan plan) {
    final activeSlots = plan.activeSlotCount;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WeeklyPlanBuilderScreen(plan: plan)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            AppCachedImage(
              imageUrl: plan.imageUrl,
              height: 56,
              width: 56,
              borderRadius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$activeSlots meals/week'
                    '${plan.startingPrice.isEmpty ? '' : ' • from ₹${plan.startingPrice}'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}