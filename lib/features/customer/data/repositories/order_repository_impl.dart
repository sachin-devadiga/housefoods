import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/customer/domain/models/order_model.dart';
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
  Future<Map<String, dynamic>> placeOneTimeOrder(Map<String, dynamic> orderData) async {
    return await _api.post(AppConstants.placeOrderEndpoint, body: orderData);
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
  Future<void> updateOrderStatus(String orderId, String newStatus, {int? preparationTime}) async {
    final endpoint = '${AppConstants.orderStatusEndpoint}/$orderId/status/';
    final body = <String, dynamic>{'status': newStatus};
    if (preparationTime != null && preparationTime > 0) {
      body['preparation_time'] = preparationTime;
    }
    await _api.post(endpoint, body: body);
  }
}
