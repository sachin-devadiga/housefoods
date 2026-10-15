import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';

class DeliveryPartnerProvider extends ChangeNotifier {
  final ApiService _api;
  final TokenService _tokenService;

  DeliveryPartnerProvider({ApiService? apiService, TokenService? tokenService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _tokenService = tokenService ?? TokenService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _availableOrders = [];
  List<Map<String, dynamic>> get availableOrders => _availableOrders;

  List<Map<String, dynamic>> _myDeliveries = [];
  List<Map<String, dynamic>> get myDeliveries => _myDeliveries;

  List<Map<String, dynamic>> _deliveryHistory = [];
  List<Map<String, dynamic>> get deliveryHistory => _deliveryHistory;

  double _totalEarnings = 0;
  double get totalEarnings => _totalEarnings;
  double _todayEarnings = 0;
  double get todayEarnings => _todayEarnings;
  double _weeklyEarnings = 0;
  double get weeklyEarnings => _weeklyEarnings;
  int _totalDeliveries = 0;
  int get totalDeliveries => _totalDeliveries;

  // Pay-model split. Added server-side after this client shipped, so both stay
  // 0 until the new response lands rather than breaking the tab.
  double _subscriptionEarnings = 0;
  double get subscriptionEarnings => _subscriptionEarnings;
  double _normalEarnings = 0;
  double get normalEarnings => _normalEarnings;

  List<Map<String, dynamic>> _payoutHistory = [];
  List<Map<String, dynamic>> get payoutHistory => _payoutHistory;

  Future<void> _ensureAuthenticated() async {
    final token = await _tokenService.getAccessToken();
    if (token != null) {
      _api.setToken(token);
    }
  }

  Future<void> fetchAllData() async {
    await _ensureAuthenticated();
    _setLoading(true);
    try {
      await Future.wait([
        _fetchAvailableOrdersInternal(),
        _fetchMyDeliveriesInternal(),
        _fetchDeliveryHistoryInternal(),
        fetchEarnings(),
      ]);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load data';
      debugPrint("fetchAllData error: $e");
    }
    _setLoading(false);
  }

  Future<void> fetchAvailableOrders() async {
    await _ensureAuthenticated();
    _setLoading(true);
    await _fetchAvailableOrdersInternal();
    _setLoading(false);
  }

  Future<void> _fetchAvailableOrdersInternal() async {
    try {
      final data = await _api.get(AppConstants.availableDeliveriesEndpoint);
      _availableOrders = _safeList(data['data']);
    } catch (e) {
      _availableOrders = [];
      _errorMessage = 'Failed to load available deliveries';
      debugPrint("fetchAvailableOrders error: $e");
    }
  }

  Future<void> acceptDelivery(dynamic orderId) async {
    final id = _parseId(orderId);
    if (id == null) return;
    await _ensureAuthenticated();
    try {
      await _api.post('${AppConstants.acceptDeliveryEndpoint}/$id/accept/');
      await Future.wait([
        fetchMyDeliveries(),
        fetchAvailableOrders(),
      ]);
    } catch (e) {
      _errorMessage = 'Failed to accept delivery';
      notifyListeners();
      debugPrint("acceptDelivery error: $e");
    }
  }

  Future<void> fetchMyDeliveries() async {
    await _ensureAuthenticated();
    _setLoading(true);
    await _fetchMyDeliveriesInternal();
    _setLoading(false);
  }

  Future<void> _fetchMyDeliveriesInternal() async {
    try {
      final data = await _api.get(AppConstants.myDeliveriesEndpoint);
      _myDeliveries = _safeList(data['data']);
    } catch (e) {
      _myDeliveries = [];
      _errorMessage = 'Failed to load deliveries';
      debugPrint("fetchMyDeliveries error: $e");
    }
  }

  Future<void> _fetchDeliveryHistoryInternal() async {
    try {
      final data = await _api.get(AppConstants.deliveryHistoryEndpoint);
      _deliveryHistory = _safeList(data['data']);
    } catch (e) {
      _deliveryHistory = [];
      debugPrint("fetchDeliveryHistory error: $e");
    }
  }

  Future<void> updateDeliveryStatus(dynamic deliveryId, String status) async {
    final id = _parseId(deliveryId);
    if (id == null) return;
    await _ensureAuthenticated();
    try {
      await _api.post(
        '${AppConstants.updateDeliveryStatusEndpoint}/$id/status/',
        body: {'delivery_status': status},
      );
      await Future.wait([
        fetchMyDeliveries(),
        _fetchDeliveryHistoryInternal(),
        fetchEarnings(),
      ]);
    } catch (e) {
      _errorMessage = 'Failed to update delivery status';
      notifyListeners();
      debugPrint("updateDeliveryStatus error: $e");
    }
  }

  Future<void> fetchEarnings() async {
    try {
      final data = await _api.get(AppConstants.deliveryEarningsEndpoint);
      _totalEarnings = _safeDouble(data['total_earnings']);
      _todayEarnings = _safeDouble(data['today_earnings']);
      _weeklyEarnings = _safeDouble(data['weekly_earnings']);
      _totalDeliveries = _safeInt(data['total_deliveries']);
      _subscriptionEarnings = _safeDouble(data['subscription_earnings']);
      _normalEarnings = _safeDouble(data['normal_earnings']);
    } catch (e) {
      _totalEarnings = 0;
      _todayEarnings = 0;
      _weeklyEarnings = 0;
      _totalDeliveries = 0;
      _subscriptionEarnings = 0;
      _normalEarnings = 0;
      debugPrint("fetchEarnings error: $e");
    }
  }

  Future<void> fetchDeliveryHistory() async {
    await _ensureAuthenticated();
    await _fetchDeliveryHistoryInternal();
    notifyListeners();
  }

  /// 7-day payout trend, oldest first, summed from real delivered orders.
  ///
  /// The earnings endpoint only returns lifetime/week totals, so the series is
  /// bucketed from [deliveryHistory] (`rider_payout` by `delivered_at` day)
  /// rather than interpolated. Days with no delivery contribute 0.
  ///
  /// ponytail: capped by the history page size (20). A rider doing >20
  /// deliveries a week sees a truncated series; replace with a per-day
  /// endpoint from DeliveryEarningsView when that ceiling matters.
  List<Map<String, dynamic>> get weeklyEarningsSeries =>
      weeklySeriesFrom(_deliveryHistory, DateTime.now());

  /// Calendar week (Mon-first), always padded to 7 so the chart reads
  /// "this week so far" against a full week, the way the chef chart does.
  @visibleForTesting
  static List<Map<String, dynamic>> weeklySeriesFrom(
    List<Map<String, dynamic>> history,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final totals = List<double>.filled(7, 0);

    for (final order in history) {
      final deliveredAt =
          order['delivered_at'] is DateTime
              ? order['delivered_at'] as DateTime
              : DateTime.tryParse(order['delivered_at']?.toString() ?? '');
      if (deliveredAt == null) continue;
      final day = DateTime(deliveredAt.year, deliveredAt.month, deliveredAt.day);
      final offset = day.difference(startOfWeek).inDays;
      if (offset < 0 || offset > 6) continue;
      final payout = order['rider_payout'];
      totals[offset] += payout is num ? payout.toDouble() : double.tryParse('$payout') ?? 0.0;
    }

    return [
      for (var i = 0; i < 7; i++)
        {'day': labels[i], 'amount': totals[i]},
    ];
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  List<Map<String, dynamic>> _safeList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _parseId(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchPayoutHistory() async {
    await _ensureAuthenticated();
    try {
      final data = await _api.get(AppConstants.deliveryPayoutsEndpoint);
      _payoutHistory = _safeList(data['data']);
      notifyListeners();
    } catch (e) {
      debugPrint("fetchPayoutHistory error: $e");
    }
  }

  double get availableBalance {
    double paidOut = 0;
    for (final p in _payoutHistory) {
      final status = p['status']?.toString().toLowerCase() ?? '';
      if (status == 'approved' || status == 'paid') {
        final raw = p['amount'];
        final amt = (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '0') ?? 0.0;
        paidOut += amt;
      }
    }
    return _totalEarnings - paidOut;
  }

  Future<void> requestPayout(double amount, Map<String, dynamic> bankDetails) async {
    await _ensureAuthenticated();
    _setLoading(true);
    try {
      await _api.post(AppConstants.deliveryPayoutsEndpoint, body: {
        'amount': amount,
        'bank_details': bankDetails,
      });
      await fetchPayoutHistory();
    } catch (e) {
      _errorMessage = 'Failed to submit payout request';
      notifyListeners();
      debugPrint("requestPayout error: $e");
    }
    _setLoading(false);
  }
}
