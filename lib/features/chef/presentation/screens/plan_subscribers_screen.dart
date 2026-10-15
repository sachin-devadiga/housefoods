import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/meal_plan_provider.dart';

/// Subscribers of this kitchen's plans.
///
/// Honest placeholder: no endpoint exposes a chef's subscribers
/// (`backend/api/subscription_views.py` is customer-scoped only). Rather than
/// invent a call or render fake names, this shows what the kitchen has
/// published and says plainly that subscriber data is not available.
///
/// TODO(backend): fetch AppConstants.chefPlanSubscribersEndpoint once it exists
/// and swap the empty state for the list.
class PlanSubscribersScreen extends StatelessWidget {
  const PlanSubscribersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planCount = context.watch<MealPlanProvider>().plans.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribers'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 72, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'No subscriber data yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                planCount == 0
                    ? 'Publish a meal plan first. Subscribers appear here once '
                        'customers subscribe to it.'
                    : 'You have $planCount published '
                        'plan${planCount == 1 ? '' : 's'}. Subscriber counts and '
                        'lists are not available in the API yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}