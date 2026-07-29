import '../../../customer/domain/models/order_model.dart';
import '../../../customer/domain/models/delivery_log_model.dart';

abstract class OrderRepository {
  Future<void> placeOrder(Map<String, dynamic> orderData);
  Future<void> placeOrderWithWallet({
    required Map<String, dynamic> orderData,
    required double walletDeduction,
  });
  Future<List<OrderModel>> getCustomerOrders(String customerId);
  Future<List<OrderModel>> getKitchenOrders(String kitchenId);
  Future<void> updateOrderStatus(String orderId, String newStatus);
  Future<void> togglePauseSubscription(String orderId, bool isPaused);

  Future<void> skipMealTransaction({
    required String userId,
    required DeliveryLogModel log,
    required double refundAmount,
    required String kitchenName,
  });

  Future<void> cancelSubscriptionTransaction({
    required String userId,
    required String orderId,
    required double refundAmount,
    required String kitchenName,
  });
}
