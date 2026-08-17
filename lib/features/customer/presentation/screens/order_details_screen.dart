import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';
import '../../../support/presentation/screens/raise_ticket_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  void _showCancellationDialog(BuildContext context) {
    // Pro-rated refund calculation for the UI
    final now = DateTime.now();
    final totalDays = order.endDate.difference(order.startDate).inDays;
    final remainingDays = order.endDate.difference(now).inDays;
    final refundAmount = (order.amount / (totalDays > 0 ? totalDays : 1)) * 
                         (remainingDays > 0 ? remainingDays : 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Subscription?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Are you sure you want to cancel your subscription? Deliveries will stop immediately.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("Estimated Refund", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    "₹${refundAmount.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                  ),
                  const Text("will be added to your HouseWallet", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Keep Subscription"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              context.read<OrderProvider>().cancelSubscription(
                order: order,
                onSuccess: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Subscription cancelled and refund processed.")),
                  );
                },
                onError: (error) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
                  );
                },
              );
            },
            child: const Text("Confirm Cancellation"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canCancel = order.status == 'active';

    return Scaffold(
      appBar: AppBar(
        title: Text("Order #${order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 24),
            _buildSectionTitle("Kitchen Details"),
            _buildKitchenInfo(),
            const SizedBox(height: 24),
            _buildSectionTitle("Subscription Details"),
            _buildPlanInfo(),
            const SizedBox(height: 24),
            _buildSectionTitle("Delivery Address"),
            _buildAddressBox(),
            const SizedBox(height: 24),
            _buildSectionTitle("Payment Summary"),
            _buildBillDetails(),
            const SizedBox(height: 40),
            _buildSupportActions(context),
            if (canCancel) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _showCancellationDialog(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
                child: const Text("Cancel Subscription"),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(order.status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _getStatusColor(order.status)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your subscription is ${order.status.toUpperCase()}.",
              style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(order.status)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppTheme.secondaryColor;
      case 'cancelled': return AppTheme.errorColor;
      case 'completed': return Colors.blue;
      default: return Colors.orange;
    }
  }

  Widget _buildKitchenInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.restaurant, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.kitchenName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text("Home-cooked with love", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildInfoRow("Plan Name", order.planName),
          _buildInfoRow("Start Date", DateFormat('dd MMM yyyy').format(order.startDate)),
          _buildInfoRow("End Date", DateFormat('dd MMM yyyy').format(order.endDate)),
          _buildInfoRow("Daily Status", order.isPaused ? "Paused" : "Active", 
                        valueColor: order.isPaused ? Colors.orange : AppTheme.secondaryColor),
        ],
      ),
    );
  }

  Widget _buildAddressBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        order.deliveryAddress,
        style: TextStyle(color: Colors.grey[800], height: 1.4),
      ),
    );
  }

  Widget _buildBillDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildBillRow("Amount Paid", "₹${order.amount.toStringAsFixed(0)}"),
          _buildBillRow("Delivery", "FREE"),
          const Divider(height: 24),
          _buildBillRow("Total", "₹${order.amount.toStringAsFixed(0)}", isTotal: true),
          const SizedBox(height: 12),
          Text(
            "Transaction ID: ${order.paymentId}",
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportActions(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RaiseTicketScreen(orderId: order.id)),
        );
      },
      icon: const Icon(Icons.help_outline),
      label: const Text("Need help with this order?"),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: Colors.blueGrey,
        side: BorderSide(color: Colors.blueGrey.shade200),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppTheme.primaryColor : Colors.black)),
        ],
      ),
    );
  }
}
