import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';

class SkipMealDialog extends StatelessWidget {
  final OrderModel order;
  final DateTime date;

  const SkipMealDialog({
    super.key,
    required this.order,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    // Pro-rated refund calculation
    final duration = order.endDate.difference(order.startDate).inDays;
    final refundAmount = order.amount / (duration > 0 ? duration : 1);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          const Icon(Icons. beach_access, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            "Skip meal for ${DateFormat('dd MMM').format(date)}?",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You will receive a refund of ₹${refundAmount.toStringAsFixed(0)} HouseCredits in your wallet.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[800], height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Skips must be requested before 10:00 PM tonight.",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Keep Meal"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
          onPressed: () {
            context.read<OrderProvider>().skipMeal(
              order: order,
              date: date,
              onSuccess: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Meal skipped. Refund credited!"),
                    backgroundColor: AppTheme.secondaryColor,
                  ),
                );
              },
              onError: (error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              },
            );
          },
          child: const Text("Confirm Skip"),
        ),
      ],
    );
  }
}
