import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  final ApiService _api;

  AdminProvider({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  int _totalUsers = 0;
  int get totalUsers => _totalUsers;

  int _totalKitchens = 0;
  int get totalKitchens => _totalKitchens;

  double _totalPlatformRevenue = 0.0;
  double get totalPlatformRevenue => _totalPlatformRevenue;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> get allUsers => _allUsers;

  List<Map<String, dynamic>> _allKitchens = [];
  List<Map<String, dynamic>> get allKitchens => _allKitchens;

  List<Map<String, dynamic>> _pendingKitchens = [];
  List<Map<String, dynamic>> get pendingKitchens => _pendingKitchens;

  List<Map<String, dynamic>> _pendingPayouts = [];
  List<Map<String, dynamic>> get pendingPayouts => _pendingPayouts;

  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> get coupons => _coupons;

  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> get banners => _banners;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchPlatformStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminDashboardEndpoint);
      _totalUsers = data['total_users'] ?? 0;
      _totalKitchens = data['total_kitchens'] ?? 0;
      _totalPlatformRevenue = (data['total_revenue'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint("Error fetching admin stats: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllUsers({String? role, String? search}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      if (role != null) params['role'] = role;
      if (search != null) params['search'] = search;
      final data = await _api.get(AppConstants.adminUsersEndpoint, queryParams: params);
      _allUsers = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error fetching all users: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllKitchens({String? status}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final data = await _api.get(AppConstants.adminKitchensEndpoint, queryParams: params);
      _allKitchens = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error fetching all kitchens: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBanners() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.bannersEndpoint);
      _banners = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error fetching banners: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBanner(Map<String, dynamic> bannerData) async {
    try {
      await _api.post(AppConstants.bannersEndpoint, body: bannerData);
      await fetchBanners();
    } catch (e) {
      debugPrint("Error adding banner: $e");
    }
  }

  Future<void> deleteBanner(int id) async {
    try {
      await _api.delete('${AppConstants.bannersEndpoint}$id/');
      await fetchBanners();
    } catch (e) {
      debugPrint("Delete banner error: $e");
    }
  }

  Future<void> fetchCoupons() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.couponsEndpoint);
      _coupons = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error coupons: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCoupon(Map<String, dynamic> couponData) async {
    try {
      await _api.post(AppConstants.couponsEndpoint, body: couponData);
      await fetchCoupons();
    } catch (e) {
      debugPrint("Error add coupon: $e");
    }
  }

  Future<void> deleteCoupon(int id) async {
    try {
      await _api.delete('${AppConstants.couponsEndpoint}$id/');
      await fetchCoupons();
    } catch (e) {
      debugPrint("Delete coupon error: $e");
    }
  }

  Future<void> fetchPendingKitchens() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminKitchensEndpoint, queryParams: {'status': 'pending'});
      _pendingKitchens = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error pending kitchens: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateKitchenStatus(int kitchenId, String newStatus) async {
    try {
      await _api.post(
        '${AppConstants.kitchenStatusEndpoint}/$kitchenId/status/',
        body: {'status': newStatus},
      );
      await fetchPendingKitchens();
      await fetchAllKitchens();
      await fetchPlatformStats();
    } catch (e) {
      debugPrint("Update kitchen error: $e");
    }
  }

  Future<void> fetchPendingPayouts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.adminPayoutsEndpoint, queryParams: {'status': 'pending'});
      _pendingPayouts = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint("Error pending payouts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePayoutStatus(int requestId, String newStatus) async {
    try {
      await _api.post(
        '${AppConstants.adminPayoutsEndpoint}$requestId/status/',
        body: {'status': newStatus},
      );
      await fetchPendingPayouts();
    } catch (e) {
      debugPrint("Error payout status: $e");
    }
  }
}
