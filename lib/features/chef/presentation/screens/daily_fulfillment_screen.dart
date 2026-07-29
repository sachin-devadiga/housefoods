import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../customer/presentation/providers/order_provider.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../../customer/domain/models/delivery_slot_model.dart';
import '../providers/chef_provider.dart';

class DailyFulfillmentScreen extends StatefulWidget {
  const DailyFulfillmentScreen({super.key});

  @override
  State<DailyFulfillmentScreen> createState() => _DailyFulfillmentScreenState();
}

class _DailyFulfillmentScreenState extends State<DailyFulfillmentScreen> {
  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chefProvider = context.read<ChefProvider>();
      if (chefProvider.myKitchen != null) {
        context.read<OrderProvider>().fetchTodayDeliveries(chefProvider.myKitchen!['id']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Worklist"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.todayDeliveries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.todayDeliveries.isEmpty) {
            return _buildEmptyState();
          }

          final groupedDeliveries = provider.getGroupedTodayDeliveries;

          return RefreshIndicator(
            onRefresh: () async => _refreshList(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedDeliveries.keys.length,
              itemBuilder: (context, index) {
                final slotId = groupedDeliveries.keys.elementAt(index);
                final orders = groupedDeliveries[slotId]!;
                final slot = availableSlots.firstWhere((s) => s.id == slotId, 
                    orElse: () => DeliverySlotModel(id: 'unknown', title: 'Standard', timeRange: 'Anytime', mealType: 'lunch'));

                return _buildSlotSection(slot, orders);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rtl_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No pending deliveries for today!",
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSection(DeliverySlotModel slot, List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: slot.mealType == 'lunch' ? Colors.blue.shade50 : Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${slot.title} (${slot.timeRange})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: slot.mealType == 'lunch' ? Colors.blue.shade800 : Colors.indigo.shade800,
                    ),
                  ),
                  Text(
                    "${orders.length} Meals to Prepare",
                    style: TextStyle(fontSize: 12, color: slot.mealType == 'lunch' ? Colors.blue.shade600 : Colors.indigo.shade600),
                  ),
                ],
              ),
              Icon(
                slot.mealType == 'lunch' ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                color: slot.mealType == 'lunch' ? Colors.blue : Colors.indigo,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...orders.map((order) => FulfillmentCard(order: order, onUpdate: _refreshList)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class FulfillmentCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onUpdate;
  const FulfillmentCard({super.key, required this.order, required this.onUpdate});

  @override
  State<FulfillmentCard> createState() => _FulfillmentCardState();
}

class _FulfillmentCardState extends State<FulfillmentCard> {
  UserModel? _customerProfile;

  @override
  void initState() {
    super.initState();
    _loadCustomerProfile();
  }

  Future<void> _loadCustomerProfile() async {
    final profile = await UserRepositoryImpl().getUser(widget.order.customerId);
    if (mounted) {
      setState(() {
        _customerProfile = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasRestrictions = _customerProfile != null && 
        (_customerProfile!.dietaryPreference != 'none' || _customerProfile!.allergies.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
      elevation: 0,
      child: Column(
        children: [
          if (hasRestrictions)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Alert: ${_customerProfile!.dietaryPreference.toUpperCase()} | ${_customerProfile!.allergies.join(', ')}",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_customerProfile?.name ?? "Loading...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.secondaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(widget.order.planName, style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.order.deliveryAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<OrderProvider>().updateStatus(widget.order.id, "Out for Delivery", widget.order.kitchenId).then((_) => widget.onUpdate());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Dispatch", style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () {}, // Action for calling customer
                      icon: const Icon(Icons.call, size: 18),
                      style: IconButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
