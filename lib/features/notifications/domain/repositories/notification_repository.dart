import '../../../notifications/domain/models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String userId, String notificationId);
  Future<void> saveNotification(String userId, NotificationModel notification);
}
