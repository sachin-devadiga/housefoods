import '../../../customer/domain/models/order_model.dart';

abstract class OrderRepository {
  Future<void> placeOrder(Map<String, dynamic> orderData);
  Future<Map<String, dynamic>> placeOneTimeOrder(Map<String, dynamic> orderData);
  Future<void> placeOrderWithWallet({
    required Map<String, dynamic> orderData,
    required double walletDeduction,
  });
  Future<List<OrderModel>> getCustomerOrders(String customerId);
  Future<List<OrderModel>> getKitchenOrders(String kitchenId);
  Future<void> updateOrderStatus(String orderId, String newStatus);
}
