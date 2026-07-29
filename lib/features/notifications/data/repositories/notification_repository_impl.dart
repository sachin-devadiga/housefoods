import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/notifications/domain/models/notification_model.dart';
import '../../../../features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiService _api;

  NotificationRepositoryImpl({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final data = await _api.get(AppConstants.notificationsEndpoint);
    final list = (data['data'] as List?) ?? [];
    return list.map((e) => NotificationModel.fromMap(e as Map<String, dynamic>, e['id'].toString())).toList();
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await _api.post('${AppConstants.markNotificationReadEndpoint}/$notificationId/read/');
  }

  @override
  Future<void> saveNotification(String userId, NotificationModel notification) async {
    // Notifications are server-generated; client saves via FCM
  }
}
