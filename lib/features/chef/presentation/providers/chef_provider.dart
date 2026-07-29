import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';

class ChefProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storageService = StorageService();

  ChefProvider({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  Map<String, dynamic>? _myKitchen;
  Map<String, dynamic>? get myKitchen => _myKitchen;

  List<Map<String, dynamic>> _myPlans = [];
  List<Map<String, dynamic>> get myPlans => _myPlans;

  List<Map<String, dynamic>> _myDishes = [];
  List<Map<String, dynamic>> get myDishes => _myDishes;

  List<Map<String, dynamic>> _payoutHistory = [];
  List<Map<String, dynamic>> get payoutHistory => _payoutHistory;

  double _totalEarnings = 0.0;
  double get totalEarnings => _totalEarnings;

  double _monthlyEarnings = 0.0;
  double get monthlyEarnings => _monthlyEarnings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchMyKitchen(String chefId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.kitchensEndpoint, queryParams: {'status': 'pending,approved,rejected'});
      final kitchens = (data['data'] as List?) ?? [];
      if (kitchens.isNotEmpty) {
        _myKitchen = kitchens.first as Map<String, dynamic>;
        await fetchMyPlans();
        await fetchDishes();
        await calculateEarnings();
      } else {
        _myKitchen = null;
      }
    } catch (e) {
      debugPrint("Error fetching kitchen: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPayoutHistory() async {
    try {
      final data = await _api.get(AppConstants.payoutsEndpoint);
      _payoutHistory = ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching payout history: $e");
    }
  }

  Future<void> submitPayoutRequest(Map<String, dynamic> requestData) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.post(AppConstants.payoutsEndpoint, body: requestData);
      await fetchPayoutHistory();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> calculateEarnings() async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      final data = await _api.get(AppConstants.ordersEndpoint, queryParams: {'status': 'active'});
      final orders = (data['data'] as List?) ?? [];

      double total = 0;
      double monthly = 0;
      final now = DateTime.now();

      for (final order in orders) {
        final orderKitchenId = order['kitchen'];
        if (orderKitchenId != null && orderKitchenId.toString() == kitchenId.toString()) {
          final raw = order['amount'];
          final amount = (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '0') ?? 0.0;
          total += amount;
          final createdAt = order['created_at'] as String?;
          if (createdAt != null) {
            final date = DateTime.tryParse(createdAt);
            if (date != null && date.month == now.month && date.year == now.year) {
              monthly += amount;
            }
          }
        }
      }

      _totalEarnings = total;
      _monthlyEarnings = monthly;
      notifyListeners();
    } catch (e) {
      debugPrint("Error calculating earnings: $e");
    }
  }

  Future<void> addGalleryImage() async {
    if (_myKitchen == null) return;
    final url = await pickAndUploadImage('kitchen_gallery');
    if (url != null && _myKitchen != null) {
      try {
        final kitchenId = _myKitchen!['id'];
        await _api.post(
          '${AppConstants.kitchenImagesEndpoint}/$kitchenId/images/',
          body: {'image_url': url},
        );
        await fetchMyKitchen(_myKitchen!['chef']?.toString() ?? '');
      } catch (e) {
        debugPrint("Error adding gallery image: $e");
      }
    }
  }

  Future<void> removeGalleryImage(String imageUrl) async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.post(
        '${AppConstants.kitchenImagesEndpoint}/$kitchenId/images/delete/',
        body: {'image_url': imageUrl},
      );
      await fetchMyKitchen(_myKitchen!['chef']?.toString() ?? '');
    } catch (e) {
      debugPrint("Error removing gallery image: $e");
    }
  }

  Future<void> fetchDishes() async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      final data = await _api.get('${AppConstants.menuItemsEndpoint}/$kitchenId/menu-items/');
      _myDishes = ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      debugPrint("Error dishes: $e");
    }
  }

  Future<void> addDish(Map<String, dynamic> dishData) async {
    if (_myKitchen == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.post(
        '${AppConstants.menuItemsEndpoint}/$kitchenId/menu-items/',
        body: dishData,
      );
      await fetchDishes();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDish(dynamic dishId) async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.delete('${AppConstants.menuItemsEndpoint}/$kitchenId/menu-items/$dishId/');
      await fetchDishes();
    } catch (e) {
      debugPrint("Error deleting dish: $e");
    }
  }

  Future<void> updateKitchenDetails(Map<String, dynamic> updatedData) async {
    _isLoading = true;
    notifyListeners();
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.put(
        '${AppConstants.kitchensEndpoint}$kitchenId/',
        body: updatedData,
      );
      await fetchMyKitchen(_myKitchen!['chef']?.toString() ?? '');
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleKitchenAvailability() async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.post(
        '${AppConstants.kitchenToggleOpenEndpoint}/$kitchenId/toggle-open/',
      );
      await fetchMyKitchen(_myKitchen!['chef']?.toString() ?? '');
    } catch (e) {
      debugPrint("Error toggling availability: $e");
    }
  }

  Future<void> saveDailyMenu(Map<String, dynamic> menuData) async {
    if (_myKitchen == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.post(
        '${AppConstants.kitchenDailyMenusEndpoint}/$kitchenId/daily-menus/',
        body: menuData,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> pickAndUploadImage(String folderPath) async {
    try {
      final File? imageFile = await _storageService.pickImage(ImageSource.gallery);
      if (imageFile != null) {
        _isLoading = true;
        notifyListeners();
        final url = await _api.uploadFile(
          AppConstants.uploadEndpoint,
          imageFile.path,
        );
        return url;
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> createKitchen(Map<String, dynamic> kitchenData) async {
    _isLoading = true;
    notifyListeners();
    try {
      kitchenData['status'] = 'pending';
      final data = await _api.post(AppConstants.kitchensEndpoint, body: kitchenData);
      _myKitchen = data;
    } catch (e) {
      debugPrint("Create kitchen error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlan(Map<String, dynamic> planData) async {
    if (_myKitchen == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final kitchenId = _myKitchen!['id'];
      await _api.post(
        '${AppConstants.plansEndpoint}/$kitchenId/plans/',
        body: planData,
      );
      await fetchMyPlans();
    } catch (e) {
      debugPrint("Add plan error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyPlans() async {
    if (_myKitchen == null) return;
    try {
      final kitchenId = _myKitchen!['id'];
      final data = await _api.get('${AppConstants.plansEndpoint}/$kitchenId/plans/');
      _myPlans = ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      debugPrint("Fetch plans error: $e");
    }
  }
}
