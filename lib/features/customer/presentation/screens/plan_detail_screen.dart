import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore_for_file: deprecated_member_use

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/address_model.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/add_address_screen.dart';
import '../../domain/models/subscription_model.dart';
import 'subscription_checkout_screen.dart';

/// Plan detail: the weekly slot table, a cadence selector bound to the plan's
/// real `prices`, an address picker, and a start-date picker that cannot offer
/// a date the backend's lead-time rule would reject.
class PlanDetailScreen extends StatefulWidget {
  final MealPlanModel plan;

  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  static const List<String> _cadenceOrder = ['week', 'month', 'year'];

  UserModel? _user;
  bool _isUserLoading = true;
  AddressModel? _selectedAddress;
  PlanPriceModel? _selectedPrice;

  /// Earliest start the backend accepts: today + subscription_min_lead_days.
  late final DateTime _earliestStart;

  /// The picker opens on this date so the customer never sees an invalid one.
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _earliestStart = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: AppConstants.subscriptionMinLeadDays));
    _startDate = _earliestStart;
    // Default to the cheapest active cadence that actually exists on the plan.
    final active = widget.plan.activePrices;
    _selectedPrice = active.isEmpty
        ? null
        : active.reduce((a, b) => a.price <= b.price ? a : b);
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
      if (user != null && user.addresses.isNotEmpty) {
        _selectedAddress = _selectedAddress ?? user.addresses.first;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(_earliestStart) ? _earliestStart : _startDate,
      // The backend rejects anything under the lead time, so the picker cannot
      // offer it in the first place.
      firstDate: _earliestStart,
      lastDate: last,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _pickAddress() {
    final addresses = _user?.addresses ?? const <AddressModel>[];
    // Previously this returned silently when the list was empty, so a customer
    // with no saved address tapped the tile and nothing happened at all. Send
    // them straight into the add flow instead.
    if (addresses.isEmpty) {
      _addAddress();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...addresses.map((addr) => ListTile(
                leading: Radio<AddressModel>(
                  value: addr,
                  groupValue: _selectedAddress,
                  onChanged: (val) {
                    setState(() => _selectedAddress = val);
                    Navigator.pop(ctx);
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                title: Text(addr.fullAddress),
                subtitle: Text(addr.label),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// AddAddressScreen pops a plain `true`, not the created address, so the new
  /// one is identified by diffing ids after a reload rather than by trusting
  /// the pop value — casting that `true` to AddressModel would crash.
  Future<void> _addAddress() async {
    final user = _user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add an address')),
      );
      return;
    }
    final before = user.addresses.map((a) => a.id).toSet();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddAddressScreen(user: user)),
    );
    if (!mounted) return;
    await _loadUser();
    if (changed != true) return;
    final fresh =
        (_user?.addresses ?? const <AddressModel>[]).where((a) => !before.contains(a.id)).toList();
    if (fresh.isNotEmpty) setState(() => _selectedAddress = fresh.first);
  }

  void _goToCheckout() {
    final price = _selectedPrice;
    final address = _selectedAddress;
    if (price == null) return;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionCheckoutScreen(
          plan: widget.plan,
          price: price,
          address: address,
          startDate: _startDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final plan = widget.plan;
    final activePrices = plan.activePrices;
    final canCheckout = _selectedPrice != null && _selectedAddress != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (plan.imageUrl.isNotEmpty)
            AppCachedImage(
              imageUrl: plan.imageUrl,
              height: 160,
              borderRadius: 14,
            ),
          const SizedBox(height: 14),
          Text(plan.kitchenName,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (plan.isVeg) ...[
                const Text('Veg  ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0E8A00), fontWeight: FontWeight.w600)),
                const Text('•  ',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              if (plan.distanceLabel != null)
                Text(plan.distanceLabel!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(plan.description, style: const TextStyle(fontSize: 13.5, color: Color(0xFF696969))),
          ],
          if (plan.inclusions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.inclusions
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(e,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Weekly schedule'),
          const SizedBox(height: 8),
          _buildSlotTable(plan),
          const SizedBox(height: 20),
          _sectionTitle('Choose billing cycle'),
          const SizedBox(height: 8),
          if (activePrices.isEmpty)
            const Text('This plan has no active billing cycle yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: [
                for (final cadence in _cadenceOrder)
                  if (plan.priceFor(cadence) != null)
                    _buildCadenceTile(plan.priceFor(cadence)!),
              ],
            ),
          const SizedBox(height: 20),
          _sectionTitle('Deliver to'),
          const SizedBox(height: 8),
          _buildAddressTile(),
          const SizedBox(height: 20),
          _sectionTitle('Start date'),
          const SizedBox(height: 8),
          _buildStartDateTile(),
          const SizedBox(height: 30),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: canCheckout ? _goToCheckout : null,
              child: Text(
                // A disabled button with no explanation reads as a broken app,
                // so say exactly what is missing.
                !canCheckout && _selectedPrice != null
                    ? 'Add a delivery address to continue'
                    : _selectedPrice == null
                        ? 'Unavailable'
                        : 'Continue · ₹${_selectedPrice!.price.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      );

  /// Mon–Sun rows with the slots a kitchen published under each day. A day
  /// with no slots shows "—" rather than a guess.
  Widget _buildSlotTable(MealPlanModel plan) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final slots = plan.activeSlots;
    if (slots.isEmpty) {
      return const Text('This kitchen has not published a weekly menu yet.',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var day = 0; day < 7; day++) ...[
            if (day > 0) const Divider(height: 1),
            _buildDayRow(day, dayNames[day], slots.where((s) => s.dayOfWeek == day).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildDayRow(int day, String dayName, List<PlanSlotModel> slots) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              dayName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: slots.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 12.5, color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slots
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                s.title.isNotEmpty ? s.title : s.mealTypeLabel,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF696969)),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCadenceTile(PlanPriceModel price) {
    final selected = _selectedPrice?.id == price.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPrice = price),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => setState(() => _selectedPrice = price),
              activeColor: AppTheme.primaryColor,
            ),
            Expanded(
              child: Text(price.cadenceLabel,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text('${price.durationDays} days',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(width: 12),
            Text('₹${price.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile() {
    final addresses = _user?.addresses ?? const <AddressModel>[];
    if (addresses.isEmpty) {
      // Must be actionable. This used to be an inert label that told the user
      // to go to their profile, while Continue sat disabled below with no
      // stated reason — a dead end with no way forward from this screen.
      return InkWell(
        onTap: _addAddress,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_location_alt_outlined,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Add a delivery address',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor)),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _pickAddress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedAddress?.label ?? '',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_selectedAddress?.fullAddress ?? '',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateTile() {
    final label =
        '${_startDate.day}/${_startDate.month}/${_startDate.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _pickStartDate,
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Plans start at least ${AppConstants.subscriptionMinLeadDays} days from today, '
            'so the kitchen can prepare your first delivery.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}