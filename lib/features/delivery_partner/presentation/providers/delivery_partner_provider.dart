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

  double _totalEarnings = 0;
  double get totalEarnings => _totalEarnings;
  double _todayEarnings = 0;
  double get todayEarnings => _todayEarnings;
  double _weeklyEarnings = 0;
  double get weeklyEarnings => _weeklyEarnings;
  int _totalDeliveries = 0;
  int get totalDeliveries => _totalDeliveries;

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
        _fetchEarnings(),
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

  Future<void> updateDeliveryStatus(dynamic deliveryId, String status) async {
    final id = _parseId(deliveryId);
    if (id == null) return;
    await _ensureAuthenticated();
    try {
      await _api.post(
        '${AppConstants.updateDeliveryStatusEndpoint}/$id/status/',
        body: {'delivery_status': status},
      );
      await fetchMyDeliveries();
    } catch (e) {
      _errorMessage = 'Failed to update delivery status';
      notifyListeners();
      debugPrint("updateDeliveryStatus error: $e");
    }
  }

  Future<void> _fetchEarnings() async {
    try {
      final data = await _api.get(AppConstants.deliveryEarningsEndpoint);
      _totalEarnings = _safeDouble(data['total_earnings']);
      _todayEarnings = _safeDouble(data['today_earnings']);
      _weeklyEarnings = _safeDouble(data['weekly_earnings']);
      _totalDeliveries = _safeInt(data['total_deliveries']);
    } catch (e) {
      _totalEarnings = 0;
      _todayEarnings = 0;
      _weeklyEarnings = 0;
      _totalDeliveries = 0;
      debugPrint("fetchEarnings error: $e");
    }
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
}
