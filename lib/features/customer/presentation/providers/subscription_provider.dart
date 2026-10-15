import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/subscription_model.dart';

/// Drives the customer subscription flow: plan discovery, the checkout quote,
/// Razorpay payment, subscribe, and the lifecycle of existing subscriptions.
///
/// Mirrors OrderProvider: loading flag, error string, ChangeNotifier. The
/// Razorpay-then-POST ordering is the same contract as
/// `OrderProvider.openCheckoutForOneTime` — payment first, then the record is
/// created with the returned payment id.
class SubscriptionProvider extends ChangeNotifier {
  final ApiService _api;
  late final Razorpay _razorpay;

  SubscriptionProvider({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<MealPlanModel> _plans = [];
  List<MealPlanModel> get plans => _plans;

  /// Plans grouped by kitchen, nearest kitchen first. The backend already
  /// returns nearest-first; grouping preserves that order because the results
  /// list is built with an insertion-ordered Map.
  Map<String, List<MealPlanModel>> get plansByKitchen {
    final grouped = <String, List<MealPlanModel>>{};
    for (final plan in _plans) {
      grouped.putIfAbsent(plan.kitchenName, () => []).add(plan);
    }
    return grouped;
  }

  List<SubscriptionModel> _mySubscriptions = [];
  List<SubscriptionModel> get mySubscriptions => _mySubscriptions;

  SubscriptionQuoteModel? _quote;
  SubscriptionQuoteModel? get quote => _quote;

  // ── Plan discovery ────────────────────────────────────────────────

  Future<void> fetchPlans({double radiusKm = 15}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get(
        AppConstants.subscriptionPlansEndpoint,
        queryParams: {'radius_km': radiusKm.toString()},
      );
      _plans = ((data['results'] as List<dynamic>?) ?? const [])
          .map((e) => MealPlanModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Quote ──────────────────────────────────────────────────────────

  /// Returns null on failure and leaves the message in [error], so the
  /// checkout screen can render the breakdown or the reason it has none.
  Future<SubscriptionQuoteModel?> fetchQuote({
    required String priceId,
    required String addressId,
  }) async {
    _isLoading = true;
    _error = null;
    _quote = null;
    notifyListeners();
    try {
      final data = await _api.post(
        AppConstants.subscriptionQuoteEndpoint,
        body: {'price': priceId, 'address': addressId},
      );
      _quote = SubscriptionQuoteModel.fromMap(data);
      return _quote;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearQuote() {
    _quote = null;
    _error = null;
    notifyListeners();
  }

  // ── My subscriptions ───────────────────────────────────────────────

  Future<void> fetchMySubscriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.mySubscriptionsEndpoint);
      _mySubscriptions = ((data['results'] as List<dynamic>?) ?? const [])
          .map((e) => SubscriptionModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────

  Future<bool> pause(String id) =>
      _lifecycle(id, AppConstants.subscriptionPauseEndpoint(id));

  Future<bool> resume(String id) =>
      _lifecycle(id, AppConstants.subscriptionResumeEndpoint(id));

  Future<bool> cancel(String id) =>
      _lifecycle(id, AppConstants.subscriptionCancelEndpoint(id));

  Future<bool> _lifecycle(String id, String endpoint) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.post(endpoint);
      await fetchMySubscriptions();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> skipMeal({
    required String id,
    required DateTime date,
    required String mealType,
    String reason = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.post(
        AppConstants.subscriptionSkipMealEndpoint(id),
        body: {
          'date': _isoDate(date),
          'meal_type': mealType,
          'reason': reason,
        },
      );
      await fetchMySubscriptions();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Razorpay + subscribe ───────────────────────────────────────────

  MealPlanModel? _pendingPlan;
  PlanPriceModel? _pendingPrice;
  String? _pendingAddressId;
  DateTime? _pendingStartDate;
  void Function(SubscriptionModel)? _onSuccess;
  void Function(String)? _onFailure;

  /// Opens Razorpay for the quoted period total. On success the subscription
  /// is created with the returned payment id — payment first, then the record,
  /// exactly as the one-time order flow does.
  void openSubscriptionCheckout({
    required MealPlanModel plan,
    required PlanPriceModel price,
    required String addressId,
    required DateTime startDate,
    required double amount,
    required String userEmail,
    required String userPhone,
    required void Function(SubscriptionModel) onSuccess,
    required void Function(String) onError,
  }) {
    _pendingPlan = plan;
    _pendingPrice = price;
    _pendingAddressId = addressId;
    _pendingStartDate = startDate;
    _onSuccess = onSuccess;
    _onFailure = onError;

    // A zero-cost plan still needs a subscription record; skip the gateway
    // rather than opening a ₹0 checkout, same as the one-time flow.
    if (amount <= 0) {
      _handlePaymentSuccess(PaymentSuccessResponse(null, null, null, null));
      return;
    }

    final options = {
      'key': AppConstants.razorpayKey,
      'amount': (amount * 100).toInt(),
      'name': 'Mealin',
      'description': '${plan.name} · ${price.cadenceLabel}',
      'prefill': {'contact': userPhone, 'email': userEmail},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
      _onFailure?.call(e.toString());
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final plan = _pendingPlan;
    final price = _pendingPrice;
    final addressId = _pendingAddressId;
    final startDate = _pendingStartDate;
    if (plan == null || price == null || addressId == null || startDate == null) {
      _onFailure?.call('No pending subscription found.');
      _clearPending();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.post(
        AppConstants.subscriptionSubscribeEndpoint,
        body: {
          'plan': plan.id,
          'price': price.id,
          'address': addressId,
          'start_date': _isoDate(startDate),
          'payment_id': response.paymentId ?? 'COD',
        },
      );
      final created = SubscriptionModel.fromMap(data);
      _clearPending();
      await fetchMySubscriptions();
      _onSuccess?.call(created);
    } catch (e) {
      _clearPending();
      _onFailure?.call(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _clearPending();
    _onFailure?.call(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _clearPending() {
    _pendingPlan = null;
    _pendingPrice = null;
    _pendingAddressId = null;
    _pendingStartDate = null;
    _onSuccess = null;
    _onFailure = null;
  }

  static String _isoDate(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}