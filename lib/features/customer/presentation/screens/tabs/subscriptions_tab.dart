import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../my_subscriptions_screen.dart';
import '../plans_browse_screen.dart';

/// Fifth bottom-nav tab. Shows a summary of what the customer is subscribed
/// to plus the entry points into browsing plans and managing subscriptions.
///
/// The provider is created here rather than in `main.dart`'s MultiProvider so
/// this feature stays self-contained; the same instance is handed to the
/// pushed screens so they share state.
class SubscriptionsTab extends StatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  final SubscriptionProvider _provider = SubscriptionProvider();

  @override
  void initState() {
    super.initState();
    _provider.fetchMySubscriptions();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SubscriptionProvider>.value(
      value: _provider,
      child: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          final live = provider.mySubscriptions
              .where((SubscriptionModel s) => !s.isCancelled)
              .toList();

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () => provider.fetchMySubscriptions(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(live),
                const SizedBox(height: 16),
                _buildBrowseButton(provider),
                const SizedBox(height: 16),
                _buildManageButton(provider),
                if (provider.mySubscriptions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Your plans',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  for (final sub in provider.mySubscriptions)
                    _buildSummaryRow(sub),
                ],
                const SizedBox(height: 90),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(List<SubscriptionModel> live) {
    final activeCount = live.where((s) => s.isActive).length;
    final pausedCount = live.where((s) => s.isPaused).length;

    String summary;
    if (live.isEmpty) {
      summary = 'No active meal plans';
    } else {
      final parts = <String>[];
      if (activeCount > 0) parts.add('$activeCount active');
      if (pausedCount > 0) parts.add('$pausedCount paused');
      summary = parts.join(' · ');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFFE64A19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.autorenew, color: Colors.white70, size: 26),
          const SizedBox(height: 10),
          Text(
            summary,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            live.isEmpty
                ? 'Subscribe to a kitchen plan and get meals on a fixed schedule.'
                : 'Pause, resume or skip meals any time.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseButton(SubscriptionProvider provider) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<SubscriptionProvider>.value(
              value: provider,
              child: const PlansBrowseScreen(),
            ),
          ),
        ),
        icon: const Icon(Icons.explore_outlined, color: Colors.white),
        label: const Text('Browse Meal Plans',
            style: TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _buildManageButton(SubscriptionProvider provider) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<SubscriptionProvider>.value(
              value: provider,
              child: const MySubscriptionsScreen(),
            ),
          ),
        ),
        icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
        label: const Text('Manage Subscriptions',
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(SubscriptionModel sub) {
    final window = sub.startDate == null || sub.endDate == null
        ? ''
        : '${sub.startDate!.day}/${sub.startDate!.month}'
            ' – ${sub.endDate!.day}/${sub.endDate!.month}/${sub.endDate!.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.planName,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    sub.kitchenName,
                    sub.cadenceLabel,
                    if (window.isNotEmpty) window,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (sub.isActive ? AppTheme.secondaryColor : Colors.grey)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sub.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: sub.isActive ? AppTheme.secondaryColor : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}