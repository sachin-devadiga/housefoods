import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../../../chat/presentation/screens/inbox_screen.dart';
import '../../../support/presentation/screens/user_tickets_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().fetchNotifications(uid);
      });
    }
  }

  void _handleNotificationTap(dynamic notification) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isEmpty) return;

    // 1. Mark as read in Firestore and local state
    context.read<NotificationProvider>().markAsRead(uid, notification.id);

    // 2. Navigate based on type
    if (notification.type == 'chat') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
    } else if (notification.type == 'support' || notification.type == 'ticket') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserTicketsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        elevation: 1,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadNotifications(),
            child: ListView.separated(
              itemCount: provider.notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = provider.notifications[index];
                return Container(
                  color: item.isRead ? Colors.transparent : AppTheme.primaryColor.withValues(alpha: 0.03),
                  child: ListTile(
                    onTap: () => _handleNotificationTap(item),
                    leading: CircleAvatar(
                      backgroundColor: _getIconColor(item.type).withValues(alpha: 0.1),
                      child: Icon(_getIcon(item.type), color: _getIconColor(item.type), size: 20),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.body, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('hh:mm a, dd MMM').format(item.timestamp),
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                        ),
                      ],
                    ),
                    trailing: !item.isRead 
                      ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle))
                      : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order': return Icons.local_shipping_outlined;
      case 'chat': return Icons.chat_bubble_outline;
      case 'promo': return Icons.local_offer_outlined;
      case 'support': return Icons.support_agent;
      default: return Icons.notifications_none;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order': return AppTheme.secondaryColor;
      case 'promo': return Colors.orange;
      case 'support': return Colors.blue;
      default: return AppTheme.primaryColor;
    }
  }
}
