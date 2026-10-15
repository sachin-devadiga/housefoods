import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/subscription_model.dart';
import '../providers/subscription_provider.dart';

/// The customer's own subscriptions: status, plan, kitchen, cadence and the
/// billing window, plus the lifecycle actions the backend exposes (pause,
/// resume, cancel) and skipping one specific scheduled meal.
class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchMySubscriptions();
    });
  }

  Future<void> _confirmAndRun(
    SubscriptionModel sub,
    Future<bool> Function() action,
    String confirmTitle,
    String confirmBody,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<SubscriptionProvider>();
    final ok = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Done' : (provider.error ?? 'Could not complete that')),
        backgroundColor: ok ? AppTheme.secondaryColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _pickMealToSkip(SubscriptionModel sub) async {
    final meals = sub.skippableMeals;
    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upcoming meals left to skip')),
      );
      return;
    }

    final picked = await showModalBottomSheet<SubscriptionMealModel>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Skip which meal?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: meals
                  .map((meal) => ListTile(
                        leading: const Icon(Icons.event_busy_outlined,
                            color: AppTheme.primaryColor),
                        title: Text(meal.title.isNotEmpty
                            ? meal.title
                            : '${meal.mealType} meal'),
                        subtitle: Text(DateFormat('EEE, d MMM').format(meal.date!)),
                        onTap: () => Navigator.pop(ctx, meal),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final ok = await context.read<SubscriptionProvider>().skipMeal(
          id: sub.id,
          date: picked.date!,
          mealType: picked.mealType,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Skipped ${picked.title.isNotEmpty ? picked.title : picked.mealType} on ${DateFormat('d MMM').format(picked.date!)}'
            : (context.read<SubscriptionProvider>().error ?? 'Could not skip that meal')),
        backgroundColor: ok ? AppTheme.secondaryColor : AppTheme.errorColor,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.secondaryColor;
      case 'paused':
        return Colors.orange.shade700;
      default:
        return Colors.grey;
    }
  }

  String _window(SubscriptionModel sub) {
    final start = sub.startDate;
    final end = sub.endDate;
    if (start == null || end == null) return 'Dates unavailable';
    final fmt = DateFormat('d MMM yyyy');
    return '${fmt.format(start)} — ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Subscriptions')),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.mySubscriptions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.mySubscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.primaryColor),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(provider.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor),
                    onPressed: () => provider.fetchMySubscriptions(),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          if (provider.mySubscriptions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_meals_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 14),
                  Text('No subscriptions yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('Browse meal plans from the Subscriptions tab',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () => provider.fetchMySubscriptions(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.mySubscriptions.length,
              itemBuilder: (context, index) =>
                  _buildCard(provider.mySubscriptions[index], provider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(SubscriptionModel sub, SubscriptionProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(sub.planName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(sub.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sub.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(sub.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(sub.kitchenName,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          _infoRow(Icons.autorenew, '${sub.cadenceLabel} · ₹${sub.pricePaid.toStringAsFixed(0)} per period'),
          _infoRow(Icons.event, _window(sub)),
          if (sub.addressText.isNotEmpty)
            _infoRow(Icons.location_on_outlined, sub.addressText),
          if (sub.isActive && sub.skippableMeals.isNotEmpty)
            _infoRow(Icons.fastfood_outlined,
                '${sub.skippableMeals.length} upcoming meal${sub.skippableMeals.length == 1 ? '' : 's'} scheduled'),
          const SizedBox(height: 8),
          Row(
            children: [
              if (sub.isActive)
                _actionButton('Pause', Icons.pause, () => _confirmAndRun(
                  sub,
                  () => provider.pause(sub.id),
                  'Pause subscription?',
                  'Deliveries stop until you resume. Your plan window does not change.',
                )),
              if (sub.isPaused)
                _actionButton('Resume', Icons.play_arrow, () => _confirmAndRun(
                  sub,
                  () => provider.resume(sub.id),
                  'Resume subscription?',
                  'Deliveries resume under the existing plan window.',
                )),
              if (sub.isActive)
                _actionButton('Skip meal', Icons.event_busy_outlined,
                    () => _pickMealToSkip(sub)),
              if (!sub.isCancelled)
                _actionButton(
                  'Cancel',
                  Icons.cancel_outlined,
                  () => _confirmAndRun(
                    sub,
                    () => provider.cancel(sub.id),
                    'Cancel subscription?',
                    'This ends all future deliveries for this plan. It cannot be undone.',
                  ),
                  isDestructive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.errorColor : AppTheme.primaryColor;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: color),
          label: Text(label, style: TextStyle(fontSize: 12.5, color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}