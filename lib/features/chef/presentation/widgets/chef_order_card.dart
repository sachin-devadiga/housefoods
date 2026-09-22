import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class ChefOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onMarkReady;
  final VoidCallback onPrintBill;

  const ChefOrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onMarkReady,
    required this.onPrintBill,
  });

  Color _progressColor() {
    switch (order.deliveryStatus.toLowerCase()) {
      case 'accepted':
        return Colors.deepPurple;
      case 'ready_for_delivery':
        return Colors.orange;
      case 'assigned':
      case 'picked_up':
        return Colors.blue;
      case 'delivered':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _progressColor();
    final ds = order.deliveryStatus.toLowerCase();
    final isCancelled = order.status.toLowerCase() == 'cancelled';
    final isNew = !isCancelled && ds == 'pending';
    final isAccepted = !isCancelled && ds == 'accepted';
    final isReady = !isCancelled && ds == 'ready_for_delivery';
    final isDispatched = !isCancelled && (ds == 'assigned' || ds == 'picked_up');
    final isDelivered = !isCancelled && ds == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isCancelled ? Colors.grey : progressColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCancelled ? 'REJECTED' : order.deliveryProgressLabel.toUpperCase(),
                  style: TextStyle(
                      color: isCancelled ? Colors.grey : progressColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dishes to prepare',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          if (order.items.isEmpty)
            const Text('Item details unavailable — check dashboard.',
                style: TextStyle(color: Colors.grey, fontSize: 13))
          else
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.secondaryColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.menuItemName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            if (item.specialInstructions.isNotEmpty)
                              Text('Note: ${item.specialInstructions}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '₹${order.amount.toStringAsFixed(0)} • ${DateFormat('dd MMM, hh:mm a').format(order.createdAt)}',
                style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (order.preparationTime > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 2),
                Text('${order.preparationTime} min',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (isNew) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrintBill,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Bill'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: BorderSide(color: Colors.blueGrey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onMarkReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('MARK READY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (!isCancelled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrintBill,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Bill'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: BorderSide(color: Colors.blueGrey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: order.customerId,
                            receiverName: order.customerName.isNotEmpty
                                ? order.customerName
                                : 'Customer',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryColor,
                      side: const BorderSide(color: AppTheme.secondaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (isReady) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 15, color: Colors.orange),
                  SizedBox(width: 6),
                  Text('Ready — waiting for delivery partner…',
                      style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            if (isDispatched) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.delivery_dining, size: 16, color: Colors.blue),
                  SizedBox(width: 6),
                  Text('Dispatched — rider picked up the order',
                      style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            if (isDelivered) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 15, color: AppTheme.secondaryColor),
                  const SizedBox(width: 6),
                  Text('Delivered successfully',
                      style: TextStyle(
                          color: AppTheme.secondaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
