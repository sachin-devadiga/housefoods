import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/navigation_service.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/support/presentation/screens/user_tickets_screen.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final token = await _getToken();
        if (token != null && message.notification != null) {
          final api = ApiService(baseUrl: AppConstants.apiBaseUrl);
          api.setToken(token);
        }
      });

      _messaging.onTokenRefresh.listen((newToken) async {
        final token = await _getToken();
        if (token != null) {
          final api = ApiService(baseUrl: AppConstants.apiBaseUrl);
          api.setToken(token);
          await api.post(AppConstants.updateFcmTokenEndpoint, body: {'fcm_token': newToken});
        }
      });
    }
  }

  static Future<String?> _getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> uploadToken(String userId) async {}

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
    }
  }
}
