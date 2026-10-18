import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/plan_subscriber.dart';
import '../providers/meal_plan_provider.dart';

/// Subscribers of this chef's plans.
///
/// Reads `chef-subscribers/` (or the per-plan variant when [planId] is given).
/// Both endpoints are scoped server-side to kitchens the caller owns, so a chef
/// sees only their own subscribers and a non-chef gets a 403 rather than a
/// silently empty list.
///
/// Four states are distinguished rather than collapsed into one spinner:
/// loading, error, empty, and populated. "No subscribers" and "could not load
/// subscribers" look identical on a phone if you only check for an empty list,
/// and a chef acting on a false "nobody has subscribed" conclusion would be
/// the real harm here.
class PlanSubscribersScreen extends StatefulWidget {
  /// Restrict to one plan. Null shows every subscriber across all plans.
  final String? planId;

  /// Shown in the app bar when [planId] is set.
  final String? planName;

  const PlanSubscribersScreen({super.key, this.planId, this.planName});

  @override
  State<PlanSubscribersScreen> createState() => _PlanSubscribersScreenState();
}

class _PlanSubscribersScreenState extends State<PlanSubscribersScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to the first frame: initState runs before the provider is
    // necessarily mounted, and calling notifyListeners during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant PlanSubscribersScreen old) {
    super.didUpdateWidget(old);
    if (old.planId != widget.planId) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<MealPlanProvider>().fetchSubscribers(
          planId: widget.planId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MealPlanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.planName ?? 'Subscribers',
          style: const TextStyle(fontSize: 20),
        ),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: provider.isLoadingSubscribers ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(MealPlanProvider provider) {
    if (provider.isLoadingSubscribers) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = provider.subscriberError;
    if (error != null) {
      return _Centred(
        icon: Icons.cloud_off,
        iconColor: Colors.orange,
        title: 'Could not load subscribers',
        message: error,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    final subscribers = provider.subscribers;
    if (subscribers.isEmpty) {
      final planCount = provider.plans.length;
      return _Centred(
        icon: Icons.people_outline,
        title: 'No subscribers yet',
        message: planCount == 0
            ? 'Publish a meal plan first. Subscribers appear here once '
                'customers subscribe to it.'
            : 'None of your published plans has a subscriber yet.',
      );
    }

    final active = subscribers.where((s) => s.isActive).length;

    return ListView.separated(
      // AlwaysScrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      // +1 for the summary header at index 0; subscribers occupy 1..n.
      itemCount: subscribers.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Summary(
            total: subscribers.length,
            active: active,
            truncated: provider.subscribersTruncated,
          );
        }
        return _SubscriberTile(subscriber: subscribers[index - 1]);
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final int total;
  final int active;
  final bool truncated;

  const _Summary({
    required this.total,
    required this.active,
    required this.truncated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.secondaryColor.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total subscriber${total == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$active active',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          if (truncated) ...[
            const SizedBox(height: 8),
            const Text(
              'Showing a partial list — there are more subscribers than '
              'were loaded.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriberTile extends StatelessWidget {
  final PlanSubscriber subscriber;

  const _SubscriberTile({required this.subscriber});

  @override
  Widget build(BuildContext context) {
    final s = subscriber;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: s.isActive ? Colors.green.shade100 : Colors.grey.shade200,
        child: Text(
          s.displayName.isEmpty ? '?' : s.displayName[0].toUpperCase(),
          style: TextStyle(
            color: s.isActive ? Colors.green.shade800 : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(_subtitle(), style: const TextStyle(fontSize: 13)),
          if (s.planName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.planName,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (s.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.address,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _currency(s.pricePaid),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: s.isActive ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              s.status.isEmpty ? 'unknown' : s.status,
              style: TextStyle(
                fontSize: 11,
                color: s.isActive ? Colors.green.shade800 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "week · from 2026-01-04 · 98xxxxxxx"
  ///
  /// Reads the `subscriber` field rather than the local alias, since this is a
  /// method and cannot see build()'s locals.
  String _subtitle() {
    final bits = <String>[];
    if (subscriber.cadenceLabel.isNotEmpty) {
      bits.add(subscriber.cadenceLabel);
    }
    if (subscriber.startDate.isNotEmpty) {
      bits.add('from ${subscriber.startDate}');
    }
    if (subscriber.customerPhone.isNotEmpty) {
      bits.add(subscriber.customerPhone);
    }
    return bits.isEmpty ? 'No further details' : bits.join(' · ');
  }

  /// Formats the rupee amount held as a string.
  ///
  /// Returns the raw text when it will not parse, rather than showing NaN or
  /// silently rendering 0 — an unreadable amount should look suspicious, not
  /// like a free subscription.
  String _currency(String raw) {
    if (raw.isEmpty) return '—';
    final value = double.tryParse(raw);
    if (value == null) return raw;
    return '₹${value.toStringAsFixed(0)}';
  }
}

/// Shared layout for the empty and error states, so both centre their content
/// the same way instead of drifting apart as each is edited.
class _Centred extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final Widget? action;

  const _Centred({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72, color: iconColor ?? Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
