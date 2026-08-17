import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';

class AdminProvider extends ChangeNotifier {
  final ApiService _api;
  final TokenService _tokenService;

  AdminProvider({ApiService? apiService, TokenService? tokenService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _tokenService = tokenService ?? TokenService();

  Future<void> _ensureAuthenticated() async {
    final token = await _tokenService.getAccessToken();
    if (token != null) {
      _api.setToken(token);
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _totalUsers = 0;
  int get totalUsers => _totalUsers;

  int _totalCustomers = 0;
  int get totalCustomers => _totalCustomers;

  int _totalChefs = 0;
  int get totalChefs => _totalChefs;

  int _totalKitchens = 0;
  int get totalKitchens => _totalKitchens;

  int _totalDeliveryPartners = 0;
  int get totalDeliveryPartners => _totalDeliveryPartners;

  int _totalOrders = 0;
  int get totalOrders => _totalOrders;

  int _activeOrders = 0;
  int get activeOrders => _activeOrders;

  double _totalPlatformRevenue = 0.0;
  double get totalPlatformRevenue => _totalPlatformRevenue;

  double _totalPayouts = 0.0;
  double get totalPayouts => _totalPayouts;

  int _pendingKitchenCount = 0;
  int get pendingKitchenCount => _pendingKitchenCount;

  int _pendingDocumentCount = 0;
  int get pendingDocumentCount => _pendingDocumentCount;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> get allUsers => _allUsers;

  List<Map<String, dynamic>> _allKitchens = [];
  List<Map<String, dynamic>> get allKitchens => _allKitchens;

  List<Map<String, dynamic>> _pendingKitchens = [];
  List<Map<String, dynamic>> get pendingKitchens => _pendingKitchens;

  List<Map<String, dynamic>> _pendingPayouts = [];
  List<Map<String, dynamic>> get pendingPayouts => _pendingPayouts;

  List<Map<String, dynamic>> _allDeliveryPartners = [];
  List<Map<String, dynamic>> get allDeliveryPartners => _allDeliveryPartners;

  List<Map<String, dynamic>> _pendingDocuments = [];
  List<Map<String, dynamic>> get pendingDocuments => _pendingDocuments;

  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> get coupons => _coupons;

  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> get banners => _banners;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> get orders => _orders;

  // ── Dashboard ──

  Future<void> fetchPlatformStats() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminDashboardEndpoint);
      _totalUsers = data['total_users'] ?? 0;
      _totalCustomers = data['total_customers'] ?? 0;
      _totalChefs = data['total_chefs'] ?? 0;
      _totalKitchens = data['total_kitchens'] ?? 0;
      _totalDeliveryPartners = data['total_delivery_partners'] ?? 0;
      _totalOrders = data['total_orders'] ?? 0;
      _activeOrders = data['active_orders'] ?? 0;
      _totalPlatformRevenue = (data['total_revenue'] ?? 0.0).toDouble();
      _totalPayouts = (data['total_payouts'] ?? 0.0).toDouble();
      _pendingKitchenCount = data['pending_kitchens'] ?? 0;
    } catch (e) {
      _errorMessage = 'Failed to load dashboard: $e';
      debugPrint("Error fetching admin stats: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Users ──

  Future<void> fetchAllUsers({String? role, String? search}) async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      if (role != null && role.isNotEmpty) params['role'] = role;
      if (search != null && search.isNotEmpty) params['search'] = search;
      final data = await _api.get(AppConstants.adminUsersEndpoint, queryParams: params);
      _allUsers = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load users: $e';
      debugPrint("Error fetching all users: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _ensureAuthenticated();
    try {
      await _api.put('${AppConstants.adminUsersEndpoint}$uid/', body: {'is_active': isActive});
      await fetchAllUsers();
    } catch (e) {
      _errorMessage = 'Failed to update user: $e';
      debugPrint("Error toggling user active: $e");
    }
  }

  // ── Kitchens ──

  Future<void> fetchAllKitchens({String? status}) async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final data = await _api.get(AppConstants.adminKitchensEndpoint, queryParams: params);
      _allKitchens = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load kitchens: $e';
      debugPrint("Error fetching all kitchens: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPendingKitchens() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminKitchensEndpoint, queryParams: {'status': 'pending'});
      _pendingKitchens = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load pending kitchens: $e';
      debugPrint("Error pending kitchens: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateKitchenStatus(int kitchenId, String newStatus) async {
    await _ensureAuthenticated();
    try {
      await _api.post(
        '${AppConstants.kitchenStatusEndpoint}/$kitchenId/status/',
        body: {'status': newStatus},
      );
      await fetchPendingKitchens();
      await fetchAllKitchens();
      await fetchPlatformStats();
    } catch (e) {
      _errorMessage = 'Failed to update kitchen: $e';
      debugPrint("Update kitchen error: $e");
    }
  }

  // ── Payouts ──

  Future<void> fetchPendingPayouts() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminPayoutsEndpoint, queryParams: {'status': 'pending'});
      _pendingPayouts = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load payouts: $e';
      debugPrint("Error pending payouts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePayoutStatus(int requestId, String newStatus) async {
    await _ensureAuthenticated();
    try {
      await _api.put(
        '${AppConstants.adminPayoutsEndpoint}$requestId/status/',
        body: {'status': newStatus},
      );
      await fetchPendingPayouts();
      await fetchPlatformStats();
    } catch (e) {
      _errorMessage = 'Failed to update payout: $e';
      debugPrint("Error payout status: $e");
    }
  }

  // ── Delivery Partners ──

  Future<void> fetchAllDeliveryPartners() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminDeliveryPartnersEndpoint);
      _allDeliveryPartners = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load riders: $e';
      debugPrint("Error fetching delivery partners: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPendingDocuments() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminDeliveryDocumentsEndpoint, queryParams: {'status': 'pending'});
      _pendingDocuments = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _pendingDocumentCount = _pendingDocuments.length;
    } catch (e) {
      _errorMessage = 'Failed to load documents: $e';
      debugPrint("Error fetching pending documents: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDocumentStatus(int documentId, String status, {String notes = ''}) async {
    await _ensureAuthenticated();
    try {
      await _api.put(
        '${AppConstants.adminDeliveryDocumentsEndpoint}$documentId/status/',
        body: {'status': status, 'verification_notes': notes},
      );
      await fetchPendingDocuments();
    } catch (e) {
      _errorMessage = 'Failed to update document: $e';
      debugPrint("Error updating document status: $e");
    }
  }

  // ── Coupons ──

  Future<void> fetchCoupons() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.couponsEndpoint);
      _coupons = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load coupons: $e';
      debugPrint("Error coupons: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCoupon(Map<String, dynamic> couponData) async {
    await _ensureAuthenticated();
    try {
      await _api.post(AppConstants.couponsEndpoint, body: couponData);
      await fetchCoupons();
    } catch (e) {
      _errorMessage = 'Failed to create coupon: $e';
      debugPrint("Error add coupon: $e");
    }
  }

  Future<void> updateCoupon(int id, Map<String, dynamic> couponData) async {
    await _ensureAuthenticated();
    try {
      await _api.put('${AppConstants.couponsEndpoint}$id/', body: couponData);
      await fetchCoupons();
    } catch (e) {
      _errorMessage = 'Failed to update coupon: $e';
      debugPrint("Error update coupon: $e");
    }
  }

  Future<void> deleteCoupon(int id) async {
    await _ensureAuthenticated();
    try {
      await _api.delete('${AppConstants.couponsEndpoint}$id/');
      await fetchCoupons();
    } catch (e) {
      _errorMessage = 'Failed to delete coupon: $e';
      debugPrint("Delete coupon error: $e");
    }
  }

  // ── Banners ──

  Future<void> fetchBanners() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.bannersEndpoint);
      _banners = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load banners: $e';
      debugPrint("Error fetching banners: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBanner(Map<String, dynamic> bannerData) async {
    await _ensureAuthenticated();
    try {
      await _api.post(AppConstants.bannersEndpoint, body: bannerData);
      await fetchBanners();
    } catch (e) {
      _errorMessage = 'Failed to create banner: $e';
      debugPrint("Error adding banner: $e");
    }
  }

  Future<void> updateBanner(int id, Map<String, dynamic> bannerData) async {
    await _ensureAuthenticated();
    try {
      await _api.put('${AppConstants.bannersEndpoint}$id/', body: bannerData);
      await fetchBanners();
    } catch (e) {
      _errorMessage = 'Failed to update banner: $e';
      debugPrint("Error updating banner: $e");
    }
  }

  Future<void> deleteBanner(int id) async {
    await _ensureAuthenticated();
    try {
      await _api.delete('${AppConstants.bannersEndpoint}$id/');
      await fetchBanners();
    } catch (e) {
      _errorMessage = 'Failed to delete banner: $e';
      debugPrint("Delete banner error: $e");
    }
  }

  // ── Orders ──

  Future<void> fetchOrders() async {
    await _ensureAuthenticated();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminOrdersEndpoint);
      _orders = (data['results'] ?? data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _errorMessage = 'Failed to load orders: $e';
      debugPrint("Error fetching orders: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
