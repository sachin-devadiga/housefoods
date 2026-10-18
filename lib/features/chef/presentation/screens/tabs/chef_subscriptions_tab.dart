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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openBuilder(plan),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(plan),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeSlots meals/week'
                          '${plan.startingPrice.isEmpty ? '' : ' • from ₹${plan.startingPrice}'}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanSubscribersScreen(
                        planId: plan.id,
                        planName: plan.name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Subscribers'),
                ),
              ),
              const VerticalDivider(width: 1),
              _buildPublishButton(plan),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) => _onMenu(value, plan),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_all_outlined, size: 20),
                      title: Text('Duplicate plan'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline,
                          size: 20, color: AppTheme.errorColor),
                      title: Text('Delete plan',
                          style:
                              TextStyle(color: AppTheme.errorColor)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A published plan is only visible to customers if the kitchen is also
  /// approved and open — that filter is enforced server-side
  /// (`subscription_views.py` filters `kitchen__status='approved'`). Say so
  /// here so a chef does not assume a Live badge means customers can see it.
  Widget _buildStatusBadge(MealPlan plan) {
    final live = plan.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (live ? Colors.green : Colors.grey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        live ? 'LIVE' : 'DRAFT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: live ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildPublishButton(MealPlan plan) {
    final provider = context.read<MealPlanProvider>();
    final publishing = plan.isActive;
    return TextButton.icon(
      onPressed: provider.isSaving ? null : () => _togglePublish(plan),
      icon: provider.isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              publishing ? Icons.pause_circle_outline : Icons.publish,
              size: 18,
              color: AppTheme.secondaryColor,
            ),
      label: Text(
        publishing ? 'Unpublish' : 'Publish',
        style: const TextStyle(color: AppTheme.secondaryColor),
      ),
    );
  }

  Future<void> _togglePublish(MealPlan plan) async {
    final provider = context.read<MealPlanProvider>();
    final publish = !plan.isActive;

    if (publish) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Publish plan?'),
          content: const Text(
            'Customers near your kitchen will be able to see and subscribe to '
            'this plan. This only happens once your kitchen is approved and open.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await provider.publishPlan(plan.id, publish);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'Plan published.' : 'Plan unpublished.'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not update the plan.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _onMenu(String value, MealPlan plan) async {
    switch (value) {
      case 'duplicate':
        final provider = context.read<MealPlanProvider>();
        provider.startDuplicate(plan);
        // openBuilder null -> the builder starts from provider.draft
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeeklyPlanBuilderScreen()),
        );
        if (mounted) _loadPlans();

      case 'delete':
        await _confirmDelete(plan);
    }
  }

  Future<void> _confirmDelete(MealPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete plan?'),
        content: Text(
          '"${plan.name}" will be permanently removed. If it already has '
          'subscribers this is not possible — unpublish it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<MealPlanProvider>();
    try {
      await provider.deletePlan(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan deleted.'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final message = provider.errorMessage ?? 'Could not delete the plan.';
      // The server answers 409 when the plan still has subscribers, because
      // the Subscription FK is PROTECT. "Unpublish instead" is the real fix,
      // so say that rather than showing a raw conflict message.
      final hasSubscribers =
          message.toLowerCase().contains('subscri') || message.contains('409');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasSubscribers
              ? 'This plan has subscribers. Unpublish it instead of deleting.'
              : message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _openBuilder(MealPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WeeklyPlanBuilderScreen(plan: plan)),
    );
    if (mounted) _loadPlans();
  }
}