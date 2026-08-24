import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/submit_review_screen.dart';
import '../screens/order_details_screen.dart';
import '../screens/subscription_calendar_screen.dart';
import '../screens/renew_subscription_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;

  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    bool isActive = order.status == 'active';
    bool isCompleted = order.status == 'completed';
    bool isOneTime = order.orderType == 'one_time';
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final daysRemaining = order.endDate.difference(DateTime.now()).inDays;
    bool isExpiringSoon = !isOneTime && isActive && daysRemaining <= 3 && daysRemaining >= 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(order: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isExpiringSoon ? Border.all(color: Colors.orange.shade300, width: 2) : null,
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
            if (isExpiringSoon)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      "Expiring in $daysRemaining days. Renew Now!",
                      style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.kitchenName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(order),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isOneTime ? "One-Time Order" : "${order.planName} Subscription",
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (isOneTime)
              Text(
                "Amount: ₹${order.amount.toStringAsFixed(0)}",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            else
              Text(
                "Valid until: ${DateFormat('dd MMM yyyy').format(order.endDate)}",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const Divider(height: 24),
            if (isOneTime)
              Row(
                children: [
                  if (isActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveTrackingScreen(order: order),
                            ),
                          );
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: const Text("Track Order"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  if (isActive) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: order.chefId.isNotEmpty ? order.chefId : order.kitchenId,
                              receiverName: order.chefName.isNotEmpty ? order.chefName : order.kitchenName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text("Message"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ],
              )
            else if (isActive)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: order.isPaused 
                              ? null 
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LiveTrackingScreen(order: order),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.location_on_outlined, size: 18),
                          label: const Text("Track Meal"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubscriptionCalendarScreen(order: order),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text("Calendar"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isExpiringSoon)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RenewSubscriptionScreen(previousOrder: order),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text("Renew Now"),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => orderProvider.togglePauseSubscription(order),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: order.isPaused ? AppTheme.secondaryColor : AppTheme.errorColor,
                              side: BorderSide(color: order.isPaused ? AppTheme.secondaryColor : AppTheme.errorColor),
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(order.isPaused ? "Resume Meals" : "Pause Meals"),
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
                                    receiverId: order.chefId.isNotEmpty ? order.chefId : order.kitchenId,
                                    receiverName: order.chefName.isNotEmpty ? order.chefName : order.kitchenName,
                                  ),
                                ),
                              );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text("Message"),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else if (isCompleted)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubmitReviewScreen(order: order),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text("Rate Experience"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RenewSubscriptionScreen(previousOrder: order),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: AppTheme.secondaryColor,
                        side: const BorderSide(color: AppTheme.secondaryColor),
                      ),
                      child: const Text("Re-Subscribe"),
                    ),
                  ),
                ],
              )
            else
              Text(
                "Subscription ${order.status.substring(0, 1).toUpperCase()}${order.status.substring(1)}",
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderModel order) {
    String label = order.status.toUpperCase();
    Color color;

    if (order.isPaused && order.status == 'active') {
      label = "PAUSED";
      color = Colors.orange;
    } else {
      switch (order.status.toLowerCase()) {
        case 'active':
          color = AppTheme.secondaryColor;
          break;
        case 'completed':
          color = Colors.blue;
          break;
        case 'pending':
          color = Colors.orange;
          break;
        default:
          color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
