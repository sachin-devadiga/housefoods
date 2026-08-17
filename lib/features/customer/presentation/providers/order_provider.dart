import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/customer/domain/models/order_model.dart';
import '../../../../features/customer/domain/models/delivery_log_model.dart';
import '../../../../features/customer/domain/repositories/order_repository.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;
  final ApiService _api;
  late Razorpay _razorpay;

  OrderProvider(this._orderRepository, {ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<OrderModel> _customerOrders = [];
  List<OrderModel> get customerOrders => _customerOrders;

  List<DeliveryLogModel> _deliveryLogs = [];
  List<DeliveryLogModel> get deliveryLogs => _deliveryLogs;

  List<OrderModel> _todayDeliveries = [];
  List<OrderModel> get todayDeliveries => _todayDeliveries;

  List<DeliveryLogModel> _kitchenDispatchHistory = [];
  List<DeliveryLogModel> get kitchenDispatchHistory => _kitchenDispatchHistory;

  Map<String, List<OrderModel>> get getGroupedTodayDeliveries {
    Map<String, List<OrderModel>> grouped = {};
    for (var order in _todayDeliveries) {
      if (!grouped.containsKey(order.deliverySlotId)) {
        grouped[order.deliverySlotId] = [];
      }
      grouped[order.deliverySlotId]!.add(order);
    }
    return grouped;
  }

  Map<String, dynamic>? _appliedCoupon;
  Map<String, dynamic>? get appliedCoupon => _appliedCoupon;
  double _discountAmount = 0.0;
  double get discountAmount => _discountAmount;

  bool _isWalletApplied = false;
  bool get isWalletApplied => _isWalletApplied;
  double _walletRedemptionAmount = 0.0;
  double get walletRedemptionAmount => _walletRedemptionAmount;

  OrderModel? _pendingOrder;
  Function(OrderModel)? _onSuccessCallback;
  Function(String)? _onErrorCallback;

  Future<void> fetchKitchenOrders(String kitchenId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _customerOrders = await _orderRepository.getKitchenOrders(kitchenId);
    } catch (e) {
      debugPrint("Error fetching kitchen orders: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomerOrders(String customerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _customerOrders = await _orderRepository.getCustomerOrders(customerId);
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodayDeliveries(String kitchenId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.ordersEndpoint, queryParams: {'status': 'active'});
      final list = (data['data'] as List?) ?? [];
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      List<OrderModel> activeOrders = list
          .map((e) => OrderModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
          .where((o) =>
              o.kitchenId == kitchenId &&
              o.status == 'active' &&
              !o.isPaused &&
              o.endDate.isAfter(startOfDay))
          .toList();

      // Simplified: just show active orders
      _todayDeliveries = activeOrders;
    } catch (e) {
      debugPrint("Error fetching today deliveries: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchKitchenDispatchHistory(String kitchenId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(
        '${AppConstants.createDeliveryLogEndpoint}?status=delivered,missed',
      );
      final list = (data['data'] as List?) ?? [];
      _kitchenDispatchHistory = list
          .map((e) => DeliveryLogModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
          .toList();
    } catch (e) {
      debugPrint("Error fetching dispatch history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDeliveryLogs(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get('${AppConstants.deliveryLogsEndpoint}/$orderId/delivery-logs/');
      final list = (data['data'] as List?) ?? [];
      _deliveryLogs = list
          .map((e) => DeliveryLogModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
          .toList();
    } catch (e) {
      debugPrint("Error delivery logs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitDailyFeedback({
    required String orderId,
    required DateTime date,
    required double rating,
    required String feedback,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')[0];
      await _api.post(AppConstants.submitFeedbackEndpoint, body: {
        'order_id': orderId,
        'date': normalizedDate,
        'rating': rating,
        'feedback': feedback,
      });
      await fetchDeliveryLogs(orderId);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String orderId, String newStatus, String kitchenId) async {
    try {
      await _orderRepository.updateOrderStatus(orderId, newStatus);
      if (newStatus == 'Delivered') {
        final now = DateTime.now();
        final normalizedDate = DateTime(now.year, now.month, now.day)
            .toIso8601String()
            .split('T')[0];
        await _api.post(AppConstants.createDeliveryLogEndpoint, body: {
          'order_id': orderId,
          'date': normalizedDate,
          'status': 'delivered',
          'refund_amount': 0,
        });
      }
      await fetchTodayDeliveries(kitchenId);
    } catch (e) {
      debugPrint("Error status update: $e");
    }
  }

  Future<void> togglePauseSubscription(OrderModel order) async {
    try {
      bool newState = !order.isPaused;
      await _orderRepository.togglePauseSubscription(order.id, newState);
      await fetchCustomerOrders(order.customerId);
    } catch (e) {
      debugPrint("Error pause: $e");
    }
  }

  Future<void> skipMeal({
    required OrderModel order,
    required DateTime date,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    final now = DateTime.now();
    final skipLimit = DateTime(date.year, date.month, date.day)
        .subtract(const Duration(hours: 2));
    if (now.isAfter(skipLimit)) {
      onError("Cut-off time passed.");
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final duration = order.endDate.difference(order.startDate).inDays;
      final dailyRate = order.amount / (duration > 0 ? duration : 1);
      final log = DeliveryLogModel(
        id: '',
        orderId: order.id,
        date: date,
        status: 'skipped',
        refundAmount: dailyRate,
      );
      await _orderRepository.skipMealTransaction(
        userId: order.customerId,
        log: log,
        refundAmount: dailyRate,
        kitchenName: order.kitchenName,
      );
      await fetchDeliveryLogs(order.id);
      onSuccess();
    } catch (e) {
      onError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelSubscription({
    required OrderModel order,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      if (now.isAfter(order.endDate)) throw "Subscription has ended.";
      final totalDays = order.endDate.difference(order.startDate).inDays;
      final remainingDays = order.endDate.difference(now).inDays;
      final refundAmount = (order.amount / (totalDays > 0 ? totalDays : 1)) *
          (remainingDays > 0 ? remainingDays : 0);
      await _orderRepository.cancelSubscriptionTransaction(
        userId: order.customerId,
        orderId: order.id,
        refundAmount: refundAmount,
        kitchenName: order.kitchenName,
      );
      await fetchCustomerOrders(order.customerId);
      onSuccess();
    } catch (e) {
      onError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyCoupon(String code, double orderAmount) async {
    _isLoading = true;
    _appliedCoupon = null;
    _discountAmount = 0.0;
    notifyListeners();
    try {
      final data = await _api.post(AppConstants.couponValidateEndpoint, body: {
        'code': code.toUpperCase(),
        'order_amount': orderAmount,
      });
      _discountAmount = (data['discount_amount'] ?? 0).toDouble();
      _appliedCoupon = data;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleWallet(bool apply, double currentTotal, double userBalance) {
    _isWalletApplied = apply;
    _walletRedemptionAmount =
        apply ? (userBalance > currentTotal ? currentTotal : userBalance) : 0.0;
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCoupon = null;
    _discountAmount = 0.0;
    _walletRedemptionAmount = 0.0;
    _isWalletApplied = false;
    notifyListeners();
  }

  double calculateFinalPayable(double baseAmount) {
    double total = baseAmount - _discountAmount - _walletRedemptionAmount;
    return total < 0 ? 0 : total;
  }

  void openCheckout({
    required OrderModel order,
    required String userEmail,
    required String userPhone,
    required Function(OrderModel) onSuccess,
    required Function(String) onError,
  }) {
    double finalPayable = calculateFinalPayable(order.amount);
    _pendingOrder = order;
    _onSuccessCallback = onSuccess;
    _onErrorCallback = onError;
    if (finalPayable == 0) {
      _handlePaymentSuccess(PaymentSuccessResponse(null, null, null, null));
      return;
    }
    var options = {
      'key': AppConstants.razorpayKey,
      'amount': (finalPayable * 100).toInt(),
      'name': 'Mealin',
      'description': 'Subscription',
      'prefill': {'contact': userPhone, 'email': userEmail}
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingOrder != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final fullAmount = _pendingOrder!.amount;
        if (_isWalletApplied && _walletRedemptionAmount > 0) {
          final orderData = _pendingOrder!.toMap();
          orderData['amount'] = fullAmount;
          await _orderRepository.placeOrderWithWallet(
            orderData: orderData,
            walletDeduction: _walletRedemptionAmount,
          );
        } else {
          await _orderRepository.placeOrder({
            ..._pendingOrder!.toMap(),
            'amount': fullAmount,
          });
        }
        final finalOrder = OrderModel(
          id: '',
          customerId: _pendingOrder!.customerId,
          kitchenId: _pendingOrder!.kitchenId,
          kitchenName: _pendingOrder!.kitchenName,
          planId: _pendingOrder!.planId,
          planName: _pendingOrder!.planName,
          amount: calculateFinalPayable(_pendingOrder!.amount),
          deliveryAddress: _pendingOrder!.deliveryAddress,
          startDate: _pendingOrder!.startDate,
          endDate: _pendingOrder!.endDate,
          status: 'active',
          paymentId: response.paymentId ?? 'WALLET',
          createdAt: DateTime.now(),
          isPaused: false,
          deliverySlotId: _pendingOrder!.deliverySlotId,
          mealType: _pendingOrder!.mealType,
        );
        removeCoupon();
        if (_onSuccessCallback != null) _onSuccessCallback!(finalOrder);
      } catch (e) {
        if (_onErrorCallback != null) _onErrorCallback!(e.toString());
      } finally {
        _isLoading = false;
        _pendingOrder = null;
        notifyListeners();
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (_onErrorCallback != null) {
      _onErrorCallback!(response.message ?? "Failed");
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}
