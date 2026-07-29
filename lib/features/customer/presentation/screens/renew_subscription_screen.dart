import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';
import 'order_success_screen.dart';

class RenewSubscriptionScreen extends StatefulWidget {
  final OrderModel previousOrder;

  const RenewSubscriptionScreen({super.key, required this.previousOrder});

  @override
  State<RenewSubscriptionScreen> createState() => _RenewSubscriptionScreenState();
}

class _RenewSubscriptionScreenState extends State<RenewSubscriptionScreen> {
  late DateTime _newStartDate;
  late DateTime _newEndDate;

  @override
  void initState() {
    super.initState();
    // Continuity logic: Start the day after the previous one ends
    _newStartDate = widget.previousOrder.endDate.add(const Duration(days: 1));
    
    // Calculate duration from previous order
    final duration = widget.previousOrder.endDate.difference(widget.previousOrder.startDate).inDays;
    _newEndDate = _newStartDate.add(Duration(days: duration));
  }

  void _handleRenewal() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    if (profile == null) return;

    final uid = profile['uid'] ?? '';
    final email = profile['email'] ?? '';
    final phone = profile['phone'] ?? '';

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final renewalOrder = OrderModel(
      id: '', 
      customerId: uid,
      kitchenId: widget.previousOrder.kitchenId,
      kitchenName: widget.previousOrder.kitchenName,
      planId: widget.previousOrder.planId,
      planName: widget.previousOrder.planName,
      amount: widget.previousOrder.amount, 
      deliveryAddress: widget.previousOrder.deliveryAddress,
      startDate: _newStartDate,
      endDate: _newEndDate,
      status: 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
      isPaused: false,
      deliverySlotId: widget.previousOrder.deliverySlotId,
      mealType: widget.previousOrder.mealType,
    );

    orderProvider.openCheckout(
      order: renewalOrder,
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
    return Scaffold(
      appBar: AppBar(title: const Text("Renew Subscription")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRenewalInfoCard(),
            const SizedBox(height: 32),
            const Text("Renewal Period", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDateRangeDisplay(),
            const SizedBox(height: 32),
            _buildBillingSummary(),
            const SizedBox(height: 48),
            context.watch<OrderProvider>().isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleRenewal,
                    child: Text("Renew for ₹${widget.previousOrder.amount.toStringAsFixed(0)}"),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenewalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.autorenew, color: AppTheme.primaryColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Renewing: ${widget.previousOrder.planName}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "From ${widget.previousOrder.kitchenName}",
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dateColumn("Starts", _newStartDate),
          const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
          _dateColumn("Ends", _newEndDate),
        ],
      ),
    );
  }

  Widget _dateColumn(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildBillingSummary() {
    return Column(
      children: [
        _summaryRow("Previous Price", "₹${widget.previousOrder.amount.toStringAsFixed(0)}"),
        _summaryRow("Platform Fee", "FREE"),
        const Divider(height: 32),
        _summaryRow("Total Payable", "₹${widget.previousOrder.amount.toStringAsFixed(0)}", isTotal: true),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppTheme.primaryColor : Colors.black)),
        ],
      ),
    );
  }
}
