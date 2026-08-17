import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/customer/domain/models/order_model.dart';
import '../../../../features/customer/domain/models/delivery_log_model.dart';
import '../../../../features/customer/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final ApiService _api;

  OrderRepositoryImpl({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  @override
  Future<void> placeOrder(Map<String, dynamic> orderData) async {
    await _api.post(AppConstants.placeOrderEndpoint, body: orderData);
  }

  @override
  Future<void> placeOrderWithWallet({
    required Map<String, dynamic> orderData,
    required double walletDeduction,
  }) async {
    orderData['wallet_deduction'] = walletDeduction;
    await _api.post(AppConstants.placeOrderWithWalletEndpoint, body: orderData);
  }

  @override
  Future<List<OrderModel>> getCustomerOrders(String customerId) async {
    final data = await _api.get(AppConstants.ordersEndpoint);
    final list = (data['data'] as List?) ?? (data['results'] as List?) ?? [];
    return list
        .map((e) => OrderModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
        .toList();
  }

  @override
  Future<List<OrderModel>> getKitchenOrders(String kitchenId) async {
    final data = await _api.get(AppConstants.ordersEndpoint, queryParams: {
      'status': 'active',
      'kitchen_id': kitchenId,
    });
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => OrderModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
        .toList();
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final endpoint = '${AppConstants.orderStatusEndpoint}/$orderId/status/';
    await _api.post(endpoint, body: {'status': newStatus});
  }

  @override
  Future<void> togglePauseSubscription(String orderId, bool isPaused) async {
    final status = isPaused ? 'paused' : 'active';
    await updateOrderStatus(orderId, status);
  }

  @override
  Future<void> skipMealTransaction({
    required String userId,
    required DeliveryLogModel log,
    required double refundAmount,
    required String kitchenName,
  }) async {
    await _api.post(AppConstants.skipMealEndpoint, body: {
      'order_id': log.orderId,
      'date': log.date.toIso8601String().split('T')[0],
      'refund_amount': refundAmount,
    });
  }

  @override
  Future<void> cancelSubscriptionTransaction({
    required String userId,
    required String orderId,
    required double refundAmount,
    required String kitchenName,
  }) async {
    await _api.post(AppConstants.cancelSubscriptionEndpoint, body: {
      'order_id': orderId,
      'refund_amount': refundAmount,
    });
  }
}
