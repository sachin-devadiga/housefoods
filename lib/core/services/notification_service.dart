import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'token_service.dart';
import '../constants/app_constants.dart';
import 'navigation_service.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/support/presentation/screens/user_tickets_screen.dart';
import '../../features/delivery_partner/presentation/screens/delivery_partner_dashboard.dart';
import '../../features/customer/presentation/screens/customer_dashboard.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static OverlayEntry? _currentOverlay;

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground notification: ${message.notification?.title}');
        _showInAppNotification(message);
      });

      _messaging.onTokenRefresh.listen((newToken) async {
        await _uploadTokenToBackend(newToken);
      });
    }
  }

  static void _showInAppNotification(RemoteMessage message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? message.data['title'] ?? '';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    _currentOverlay?.remove();
    _currentOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIcon(message.data['type']), color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _currentOverlay?.remove();
                    _currentOverlay = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
    Future.delayed(const Duration(seconds: 4), () {
      _currentOverlay?.remove();
      _currentOverlay = null;
    });
  }

  static IconData _getIcon(String? type) {
    switch (type) {
      case 'chat': return Icons.chat;
      case 'ticket': return Icons.support_agent;
      case 'new_delivery':
      case 'delivery_update': return Icons.delivery_dining;
      case 'order_update':
      case 'delivery_status_changed': return Icons.receipt_long;
      default: return Icons.notifications;
    }
  }

  static Future<void> uploadToken(String userId) async {
    final token = await _getToken();
    if (token != null) {
      await _uploadTokenToBackend(token);
    }
  }

  static Future<void> _uploadTokenToBackend(String fcmToken) async {
    try {
      final tokenService = TokenService();
      final accessToken = await tokenService.getAccessToken();
      if (accessToken == null) return;
      final api = ApiService(baseUrl: AppConstants.apiBaseUrl);
      api.setToken(accessToken);
      await api.post(AppConstants.updateFcmTokenEndpoint, body: {'fcm_token': fcmToken});
      api.dispose();
    } catch (e) {
      debugPrint('Failed to upload FCM token: $e');
    }
  }

  static Future<String?> _getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'chat') {
      final senderId = data['senderId'];
      final senderName = data['senderName'] ?? 'Chat';
      if (senderId != null) {
        NavigationService.navigateTo(
          MaterialPageRoute(
            builder: (_) => ChatScreen(receiverId: senderId, receiverName: senderName),
          ),
        );
      }
    } else if (type == 'ticket') {
      NavigationService.navigateTo(
        MaterialPageRoute(builder: (_) => const UserTicketsScreen()),
      );
    } else if (type == 'new_delivery' || type == 'delivery_update') {
      NavigationService.navigateTo(
        MaterialPageRoute(builder: (_) => const DeliveryPartnerDashboard()),
      );
    } else if (type == 'order_update' || type == 'delivery_status_changed') {
      NavigationService.navigateTo(
        MaterialPageRoute(builder: (_) => const CustomerDashboard()),
      );
    }
  }
}
