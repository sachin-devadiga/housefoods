import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/address_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/add_address_screen.dart';
import '../../domain/models/kitchen_model.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/subscription_plan_model.dart';
import '../../domain/models/delivery_slot_model.dart';
import '../providers/order_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final KitchenModel kitchen;
  final SubscriptionPlanModel plan;

  const CheckoutScreen({super.key, required this.kitchen, required this.plan});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  final _formKey = GlobalKey<FormState>();
  
  UserModel? _user;
  AddressModel? _selectedAddress;
  DeliverySlotModel? _selectedSlot;
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firebaseUid = authProvider.userProfile?['uid'] ?? '';
    if (firebaseUid.isNotEmpty) {
      final userData = await UserRepositoryImpl().getUser(firebaseUid);
      if (mounted) {
        setState(() {
          _user = userData;
          _isUserLoading = false;
          if (_user != null && _user!.addresses.isNotEmpty) {
            _selectedAddress = _user!.addresses.first;
          }
        });
      }
    }
  }

  void _applyCoupon() async {
    if (_couponController.text.trim().isEmpty) return;
    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      await provider.applyCoupon(_couponController.text.trim(), widget.plan.price);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _processPayment() {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a delivery address")),
      );
      return;
    }

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a delivery slot")),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    if (profile == null) return;

    final uid = profile['uid'] ?? '';
    final email = profile['email'] ?? 'customer@housefoods.com';
    final phone = profile['phone'] ?? '';

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final order = OrderModel(
      id: '', 
      customerId: uid,
      kitchenId: widget.kitchen.id,
      kitchenName: widget.kitchen.name,
      planId: widget.plan.id,
      planName: widget.plan.name,
      amount: widget.plan.price, 
      deliveryAddress: "${_selectedAddress!.houseNo}, ${_selectedAddress!.fullAddress}",
      startDate: _startDate,
      endDate: _startDate.add(Duration(days: widget.plan.durationDays)),
      status: 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
      deliverySlotId: _selectedSlot!.id,
      mealType: _selectedSlot!.mealType,
    );

    orderProvider.openCheckout(
      order: order,
      userEmail: email,
      userPhone: phone,
      onSuccess: (finalOrder) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(order: finalOrder),
          ),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: _isUserLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Plan Summary"),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              
              _buildSectionHeader("Delivery Address", () {
                if (_user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!)),
                  ).then((_) => _loadUser());
                }
              }, actionLabel: "+ Add New"),
              _buildAddressSelector(),
              
              const SizedBox(height: 24),
              _buildSectionTitle("Subscription Starts On"),
              _buildDatePicker(),
              
              const SizedBox(height: 24),
              _buildSectionTitle("Preferred Delivery Slot"),
              _buildSlotSelector(),
              
              const SizedBox(height: 24),
              _buildSectionTitle("HouseWallet"),
              _buildWalletSection(orderProvider),
              
              const SizedBox(height: 24),
              _buildSectionTitle("Offers & Benefits"),
              _buildCouponSection(orderProvider),
              
              const SizedBox(height: 40),
              _buildBillDetails(orderProvider),
              const SizedBox(height: 30),
              
              orderProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _processPayment,
                      child: Text("Pay ₹${orderProvider.calculateFinalPayable(widget.plan.price).toStringAsFixed(0)}"),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap, {required String actionLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: Text(actionLabel, style: const TextStyle(color: AppTheme.primaryColor))),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSlotSelector() {
    return Column(
      children: [
        _buildSlotGroup("Lunch Slots", availableSlots.where((s) => s.mealType == 'lunch').toList()),
        const SizedBox(height: 12),
        _buildSlotGroup("Dinner Slots", availableSlots.where((s) => s.mealType == 'dinner').toList()),
      ],
    );
  }

  Widget _buildSlotGroup(String title, List<DeliverySlotModel> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: slots.map((slot) {
            bool isSelected = _selectedSlot?.id == slot.id;
            return ChoiceChip(
              label: Column(
                children: [
                  Text(slot.title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  Text(slot.timeRange, style: const TextStyle(fontSize: 10)),
                ],
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              onSelected: (val) => setState(() => _selectedSlot = val ? slot : null),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAddressSelector() {
    if (_user == null || _user!.addresses.isEmpty) {
      return InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!))).then((_) => _loadUser());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.errorColor.withValues(alpha: 0.05),
          ),
          child: const Row(
            children: [
              Icon(Icons.location_off, color: AppTheme.errorColor),
              SizedBox(width: 12),
              Text("No address found. Tap to add.", style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _user!.addresses.length,
        itemBuilder: (context, index) {
          final addr = _user!.addresses[index];
          bool isSelected = _selectedAddress?.id == addr.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedAddress = addr),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(addr.label == 'Home' ? Icons.home : Icons.work, size: 14, color: isSelected ? AppTheme.primaryColor : Colors.grey),
                      const SizedBox(width: 4),
                      Text(addr.label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("${addr.houseNo}, ${addr.fullAddress}", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime.now().add(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) setState(() => _startDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontSize: 16)),
            const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          const Icon(Icons.restaurant, size: 40, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("From ${widget.kitchen.name}", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection(OrderProvider provider) {
    if (_user == null || _user!.walletBalance <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: provider.isWalletApplied ? AppTheme.primaryColor : Colors.grey[300]!)),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Use HouseCredits", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Available: ₹${_user!.walletBalance.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ])),
          Switch(value: provider.isWalletApplied, activeThumbColor: AppTheme.primaryColor, onChanged: (val) => provider.toggleWallet(val, widget.plan.price - provider.discountAmount, _user!.walletBalance)),
        ],
      ),
    );
  }

  Widget _buildCouponSection(OrderProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: provider.appliedCoupon != null ? AppTheme.secondaryColor : Colors.grey[300]!)),
      child: Row(children: [
        const Icon(Icons.local_offer_outlined, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: provider.appliedCoupon == null 
          ? TextField(controller: _couponController, decoration: const InputDecoration(hintText: "Enter Promo Code", border: InputBorder.none), textCapitalization: TextCapitalization.characters)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.appliedCoupon!['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text("Coupon Applied", style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
            ])),
        TextButton(onPressed: provider.appliedCoupon == null ? _applyCoupon : () => provider.removeCoupon(), child: Text(provider.appliedCoupon == null ? "APPLY" : "REMOVE", style: TextStyle(color: provider.appliedCoupon == null ? AppTheme.primaryColor : Colors.red, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildBillDetails(OrderProvider provider) {
    double base = widget.plan.price;
    return Column(children: [
      _buildBillRow("Subtotal", "₹${base.toStringAsFixed(0)}"),
      if (provider.discountAmount > 0) _buildBillRow("Coupon Discount", "-₹${provider.discountAmount.toStringAsFixed(0)}", isDiscount: true),
      if (provider.walletRedemptionAmount > 0) _buildBillRow("HouseCredits", "-₹${provider.walletRedemptionAmount.toStringAsFixed(0)}", isDiscount: true),
      _buildBillRow("Delivery Fee", "FREE"),
      const Divider(height: 30),
      _buildBillRow("Total Amount", "₹${provider.calculateFinalPayable(base).toStringAsFixed(0)}", isTotal: true),
    ]);
  }

  Widget _buildBillRow(String label, String value, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppTheme.primaryColor : (isDiscount ? AppTheme.secondaryColor : Colors.black))),
    ]));
  }
}
